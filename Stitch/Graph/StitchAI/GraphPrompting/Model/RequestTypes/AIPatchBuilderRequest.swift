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

// MARK: - Work item for iterative layer processing
private struct LayerWorkItem {
    let layers: [AIGraphData_V0.LayerData]
    let parentId: UUID?
}

extension Array where Element == AIGraphData_V0.LayerData {
    func createLayerNodes(layerGroupId: UUID?,
                          nodesDict: inout [UUID: NodeEntity],
                          stateVarConnections: inout [String: [NodeIOCoordinate]],
                          isStreaming: Bool) {
        
        // MARK: VERY IMPORTANT: Use iterative approach with queue instead of recursion to avoid blowing up actor's thread-memory (512 KB; vs main thread's 8 MB)
        var queue = [LayerWorkItem(layers: self, parentId: layerGroupId)]
        
        while !queue.isEmpty {
            let workItem = queue.removeFirst()
            
            for layerData in workItem.layers {
                guard let layer = layerData.node_name.value.layer else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    continue
                }
                
                let layerNodeEntity = layer
                    .createDefaultLayerNodeEntity(nodeId: UUID(layerData.node_id) ?? UUID(),
                                                  layerGroupId: workItem.parentId)
                
                let nodeEntity = NodeEntity(id: layerNodeEntity.id,
                                            nodeTypeEntity: .layer(layerNodeEntity),
                                            title: layerData.suggested_title ?? "")
                
                nodesDict.updateValue(nodeEntity,
                                      forKey: layerNodeEntity.id)
                
                for portDerivation in layerData.custom_layer_input_values {
                    let coordinate = portDerivation.coordinate
                    
                    for inputData in portDerivation.inputData {
                        do {
                            // Parse actions at this input, which may include patch data in the event of view events
                            try nodesDict.updateWithEventData(inputData,
                                                              layerInputCoordinate: .init(portType: .keyPath(coordinate),
                                                                                          nodeId: layerNodeEntity.id),
                                                              varName: nil,
                                                              stateVarConnections: &stateVarConnections,
                                                              isStreaming: isStreaming)
                        } catch {
                            if !isStreaming {
                                // TODO: need to handle errors silently
                                fatalErrorIfDebug("createLayerNodes error: \(error)")
                            }
                        }
                    }
                }
                
                // Add children to queue instead of recursing
                if let children = layerData.children {
                    queue.append(LayerWorkItem(layers: children, parentId: layerNodeEntity.id))
                }
            }
        }
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
        var lastStreamedLayerId: UUID?
        let isLayerStreamingComplete = !(isStreaming && self.graphData.patchNodes.isEmpty)
        
        // Instantiate new GraphEntity instance, starting with known patch nodes
        var graphEntity = GraphEntity.createEmpty()
        graphEntity.id = docId
        graphEntity.name = currentGraphEntity.name
        graphEntity.nodes = self.graphData.patchNodes
        
        // The last parsed layer node during a stream might have incomplete data, we mark this as to not impact streaming performance
        if !isLayerStreamingComplete {
           // Non-empty patch nodes mean layer data is exhaustive{
            lastStreamedLayerId = self.graphData.layer_data_list.lastLeafLayer
        }

        var nodesDict = graphEntity.nodes.reduce(into: [UUID: NodeEntity]()) { result, nodeEntity in
            result.updateValue(nodeEntity, forKey: nodeEntity.id)
        }

        // create nested layer nodes in graph
        self.graphData.layer_data_list
            .createLayerNodes(layerGroupId: nil,
                              nodesDict: &nodesDict,
                              stateVarConnections: &viewStatePatchConnections,
                              isStreaming: isStreaming)
        
        graphEntity.nodes = Array(nodesDict.values)
        
        // Create nested sidebar layer data
        let newSidebarData = self.graphData.layer_data_list.compactMap {
            $0.createSidebarLayerData()
        }
        
        graphEntity.orderedSidebarLayers = newSidebarData
        
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
        
        // Reuse IDs from existing graph when possible--this allows us to reuse IDs during streaming
        let finalGraphEntity = currentGraphEntity
            .mergeWithStreamedGraph(graphEntity,
                                    lastStreamedLayerId: lastStreamedLayerId,
                                    isLayerStreamingComplete: isLayerStreamingComplete,
                                    isFullStreamComplete: !isStreaming)
        
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
