//
//  AIPatchBuilderRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

enum AIPatchBuilderRequestError: Error {
    case nodeIdNotFound
}


struct AIPatchBuilderFunctionInputs: Codable {
    let swiftui_source_code: String
    let layer_data_list: String
}

struct AIPatchBuilderFunctionInputsSchema: Encodable {
    let swiftui_source_code = OpenAISchema(type: .string)
    
    // MARK: string because no nesting support in structured outputs
    let layer_data_list = OpenAISchema(type: .string)
}

extension Array where Element == AIGraphData_V0.LayerData {
    func createLayerNodes(layerGroupId: UUID?,
                          nodesDict: [UUID: NodeEntity],
                          stateVarConnections: [String: [NodeIOCoordinate]],
                          isStreaming: Bool,
                          depth: Int = 0) -> (nodes: [UUID: NodeEntity], connections: [String: [NodeIOCoordinate]]) {

        var nodesDict = nodesDict
        var stateVarConnections = stateVarConnections

        // MARK: Instrumentation for stack overflow debugging
        log("createLayerNodes: depth=\(depth), layerCount=\(self.count), nodeDictSize=\(nodesDict.count)")

        // MARK: VERY IMPORTANT: DEEPLY NESTED DICTIONARY MUTATIONS WERE CAUSING `EXC_BAD_ACCESS` WITH THE PHONE DIAL DEMO, SO WE NOW GATHER AND APPLY PENDING MUTATIONS AT THE VERY END. See "Phases 1-4".
        // PHASE 1: Collect all layer nodes (no dictionary mutations)
        var pendingNodes: [UUID: NodeEntity] = [:]
        var pendingEventData: [(layerNodeId: UUID,
                                coordinate: CurrentAIGraphData.LayerInputType,
                                events: [PatchSyntaxResultType])] = []

        for layerData in self {
            guard let layer = layerData.node_name.value.layer else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                continue
            }

            let layerNodeEntity = layer
                .createDefaultLayerNodeEntity(nodeId: UUID(layerData.node_id) ?? UUID(),
                                              layerGroupId: layerGroupId)

            let nodeEntity = NodeEntity(id: layerNodeEntity.id,
                                        nodeTypeEntity: .layer(layerNodeEntity),
                                        title: layerData.suggested_title ?? "")

            // Store node without mutating nodesDict yet
            pendingNodes[layerNodeEntity.id] = nodeEntity

            // Collect all input data updates for this layer
            for portDerivation in layerData.custom_layer_input_values {
                let coordinate = portDerivation.coordinate
                let events = portDerivation.inputData

                pendingEventData.append((
                    layerNodeId: layerNodeEntity.id,
                    coordinate: coordinate,
                    events: events
                ))
            }
        }

        // PHASE 2: Apply all nodes at once (single merge operation)
        log("createLayerNodes: depth=\(depth), Phase 2: merging \(pendingNodes.count) nodes into dict of size \(nodesDict.count)")
        nodesDict.merge(pendingNodes) { _, new in new }

        // PHASE 3: Apply all input data updates (no nested closures)
        log("createLayerNodes: depth=\(depth), Phase 3: applying \(pendingEventData.count) input data updates")
        for eventData in pendingEventData {
            for inputData in eventData.events {
                do {
                    // Parse actions at this input, which may include patch data in the event of view events
                    let result = try Dictionary<UUID, NodeEntity>.updateWithEventData(
                        inputData,
                        nodesDict: nodesDict,
                        layerInputCoordinate: .init(portType: .keyPath(eventData.coordinate),
                                                    nodeId: eventData.layerNodeId),
                        varName: nil,
                        stateVarConnections: stateVarConnections,
                        isStreaming: isStreaming)
                    nodesDict = result.nodes
                    stateVarConnections = result.connections
                } catch {
                    if !isStreaming {
                        // TODO: need to handle errors silently
                        fatalErrorIfDebug("createLayerNodes error: \(error)")
                    }
                }
            }
        }

        // PHASE 4: Recurse on children (after all mutations complete)
        log("createLayerNodes: depth=\(depth), Phase 4: recursing on children")
        for layerData in self {
            if let children = layerData.children {
                guard let layerNodeId = UUID(layerData.node_id) else { continue }

                log("createLayerNodes: depth=\(depth), recursing into depth=\(depth + 1) with \(children.count) children")
                let result = children.createLayerNodes(
                    layerGroupId: layerNodeId,
                    nodesDict: nodesDict,
                    stateVarConnections: stateVarConnections,
                    isStreaming: isStreaming,
                    depth: depth + 1)
                nodesDict = result.nodes
                stateVarConnections = result.connections
            }
        }

        log("createLayerNodes: depth=\(depth), complete with \(nodesDict.count) total nodes")
        return (nodesDict, stateVarConnections)
    }
}

struct StitchAIGraphEntityResult {
    let graph: GraphEntity
    let errors: [SwiftUISyntaxError]
}

extension SwiftSyntaxActionsResult {
    @MainActor
    func applyAIGraph(to document: StitchDocumentViewModel,
                      viewStatePatchConnections: [String : [NodeIOCoordinate]],
                      currentGraphEntity: GraphEntity,
                      isStreaming: Bool) {
        // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
        self.processAIGraph(document: document,
                            currentGraphEntity: currentGraphEntity,
                            isStreaming: isStreaming)
        document.encodeProjectInBackground()
    }
    
    @MainActor
    func processAIGraph(document: StitchDocumentViewModel,
                        currentGraphEntity: GraphEntity,
                        isStreaming: Bool) {

        let processLogic = {
            let result = self.createAIGraph(from: currentGraphEntity,
                                            docId: document.graph.id.value,
                                            viewPortCenter: document.viewPortCenter,
                                            groupNodeFocused: document.groupNodeFocused?.groupNodeId,
                                            isStreaming: isStreaming)
            
            // Update topological data--needs to be forced here because of script building using this data
            document.graph.update(from: result.graph)
            document.graph.updateGraphData(document)
            
            // Report errors
            if !isStreaming {
                result.errors.displayErrors(document: document)
                
                // TODO: debug issues with proper graph eval after a streaming request ends; theoretically a prototype restart should not be necessary
                document.onPrototypeRestart(document: document)
            }
        }
        
        if isStreaming {
            withAnimation(.linear(duration: STREAMING_ANIMATION_SPEED)) {
                processLogic()
            }
        } else {
            processLogic()
        }
    }
    
    func createAIGraph(from currentGraphEntity: GraphEntity,
                       docId: UUID,
                       viewPortCenter: CGPoint,
                       groupNodeFocused: UUID?,
                       isStreaming: Bool) -> StitchAIGraphEntityResult {
        var viewStatePatchConnections = self.graphData.viewStatePatchConnections

        // Instantiate new GraphEntity instance, starting with known patch nodes
        var graphEntity = GraphEntity.createEmpty()
        graphEntity.id = docId
        graphEntity.name = currentGraphEntity.name
        graphEntity.nodes = self.graphData.patchNodes

        var nodesDict = graphEntity.nodes.reduce(into: [UUID: NodeEntity]()) { result, nodeEntity in
            result.updateValue(nodeEntity, forKey: nodeEntity.id)
        }

        // create nested layer nodes in graph
        let layerNodesResult = self.graphData.layer_data_list
            .createLayerNodes(layerGroupId: nil,
                              nodesDict: nodesDict,
                              stateVarConnections: viewStatePatchConnections,
                              isStreaming: isStreaming)
        nodesDict = layerNodesResult.nodes
        viewStatePatchConnections = layerNodesResult.connections

        graphEntity.nodes = Array(nodesDict.values)
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        let repositionedNodes = graphEntity.nodes.positionAIGeneratedNodesDuringApply(
            viewPortCenter: viewPortCenter)
        graphEntity.nodes = repositionedNodes
        
        // Make group Id map current context
        graphEntity.nodes = graphEntity.nodes.map { nodeEntity in
            var nodeEntity = nodeEntity
            nodeEntity.canvasEntityMutator { canvasEntity in
                var canvasEntity = canvasEntity
                canvasEntity.parentGroupNodeId = groupNodeFocused
                return canvasEntity
            }
            return nodeEntity
        }
        
        var finalGraphEntity: GraphEntity
        
        if isStreaming {
            // Reuse IDs from existing graph when possible--this allows us to reuse IDs during streaming
            finalGraphEntity = currentGraphEntity
                .mergeWithStreamedGraph(graphEntity)
        } else {
            // Infer data directly
            finalGraphEntity = graphEntity
            
            // Create nested sidebar layer data
            let newSidebarData = self.graphData.layer_data_list.compactMap {
                $0.createSidebarLayerData()
            }
            
            finalGraphEntity.orderedSidebarLayers = newSidebarData
        }
        
        // TODO: come back to sidebar selection

        //        document.graph.layersSidebarViewModel.primary = newNodesForSelectedOldNodes
//        log("Restored sidebar selection for \(newNodesForSelectedOldNodes.count) matched nodes")

        return .init(graph: finalGraphEntity,
                     errors: caughtErrors)
    }
}

extension Array where Element == SwiftUISyntaxError {
    @MainActor
    func displayErrors(document: StitchDocumentViewModel) {
 
#if STITCH_AI_TESTING || DEBUG || DEV_DEBUG
        // In debug builds, show all errors (including silent ones) for development
        if !self.isEmpty {
            let caughtErrorsString = self.reduce(into: "") { stringBuilder, error in
                stringBuilder += "\n\(error)"
            }
            
            document.storeDelegate?.alertState.stitchFileError = .unknownError("Warnings for the following unknown concepts:\(caughtErrorsString)")
        }
#else
        // Filter out silent errors - only show errors that should interrupt the user
        let nonSilentErrors = self.filter { !$0.shouldFailSilently }
        
        // In production builds, only show non-silent errors to users
        if !nonSilentErrors.isEmpty {
            let nonSilentErrorsString = nonSilentErrors.reduce(into: "") { stringBuilder, error in
                stringBuilder += "\n\(error)"
            }
            
            document.storeDelegate?.alertState.stitchFileError = .unknownError("Warnings for the following unknown concepts:\(nonSilentErrorsString)")
        }
#endif
    }
}

extension NodeIOCoordinate {
    init(from aiPatchCoordinate: CurrentAIGraphData.NodeIndexedCoordinate,
         idMap: [String : UUID]) throws {
        guard let newId = idMap.get(aiPatchCoordinate.node_id) else {
            log("updateCustomInputValueFromAI: idMap did not have aiPatchCoordinate.node_id \(aiPatchCoordinate.node_id), idMap: \(idMap)")
            throw SwiftUISyntaxError.viewNodeNotFound
        }
        
        self.init(portId: aiPatchCoordinate.port_index,
                  nodeId: newId)
    }
    
    init(from aiLayerCoordinate: CurrentAIGraphData.LayerInputCoordinate,
         idMap: [String : UUID]) throws {
        guard let newId = idMap.get(aiLayerCoordinate.layer_id) else {
            fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have aiLayerCoordinate.layer_id \(aiLayerCoordinate.layer_id), idMap: \(idMap)")
            throw AIPatchBuilderRequestError.nodeIdNotFound
        }
        
        let portType = AIGraphData_V0.NodeIOPortType
            .keyPath(.init(layerInput: aiLayerCoordinate.input_port_type.layerInput,
                           portType: aiLayerCoordinate.input_port_type.portType ))
        
        let migratedPortType = try portType.convert(to: NodeIOPortType.self)
        
        self.init(portType: migratedPortType,
                  nodeId: newId)
    }
}
