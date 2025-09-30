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
                          isStreaming: Bool) -> (nodes: [UUID: NodeEntity], stateVars: [String: [NodeIOCoordinate]]) {
        // Create defensive copy to avoid concurrent modification during streaming
        let layerDataCopy = Array(self)

        // Work with local mutable copies instead of inout parameters
        var localNodesDict = nodesDict
        var localStateVarConnections = stateVarConnections

        for layerData in layerDataCopy {
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

            localNodesDict.updateValue(nodeEntity,
                                       forKey: layerNodeEntity.id)

            // Create defensive copy of input values to prevent concurrent modification crashes
            streamingLog("🔵 LAYER: About to access custom_layer_input_values, count: \(layerData.custom_layer_input_values.count)")
            let customInputValues: [LayerPortDerivation] = layerData.custom_layer_input_values.map { $0 }
            streamingLog("🔵 LAYER: Created customInputValues copy, count: \(customInputValues.count)")

            for (index, portDerivation) in customInputValues.enumerated() {
                streamingLog("🔵 LAYER: Processing portDerivation [\(index)/\(customInputValues.count)]")
                streamingLog("🔵 LAYER: About to access portDerivation.coordinate")
                let coordinate = portDerivation.coordinate
                streamingLog("🔵 LAYER: Got coordinate, about to access inputData")

                // Create defensive copy of input data
                let inputDataCopy: [PatchSyntaxResultType] = portDerivation.inputData.map { $0 }
                streamingLog("🔵 LAYER: Created inputDataCopy, count: \(inputDataCopy.count)")

                for inputData in inputDataCopy {
                    do {
                        // Parse actions at this input, which may include patch data in the event of view events
                        // Use local copies to avoid inout parameter issues
                        var tempNodesDict = localNodesDict
                        var tempStateVarConnections = localStateVarConnections

                        try tempNodesDict.updateWithEventData(
                            inputData,
                            layerInputCoordinate: .init(portType: .keyPath(coordinate),
                                                        nodeId: layerNodeEntity.id),
                            varName : nil,
                            stateVarConnections: &tempStateVarConnections,
                            isStreaming: isStreaming)

                        // Update the local variables after successful mutation
                        localNodesDict = tempNodesDict
                        localStateVarConnections = tempStateVarConnections
                    } catch {
                        if !isStreaming {
                            // TODO: need to handle errors silently
                            fatalErrorIfDebug("createLayerNodes error: \(error)")
                        }
                    }
                }
            }


            if let children = layerData.children {
                let (updatedNodes, updatedStateVars) = children
                    .createLayerNodes(layerGroupId: layerNodeEntity.id,
                                      nodesDict: localNodesDict,
                                      stateVarConnections: localStateVarConnections,
                                      isStreaming: isStreaming)

                localNodesDict = updatedNodes
                localStateVarConnections = updatedStateVars
            }
        }

        return (nodes: localNodesDict, stateVars: localStateVarConnections)
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
                      isStreaming: Bool) {
        // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
        self.processAIGraph(document: document,
                            isStreaming: isStreaming)
        document.encodeProjectInBackground()
    }
    
    @MainActor
    func processAIGraph(document: StitchDocumentViewModel,
                        isStreaming: Bool) {

        let processLogic = {
            let result = self.createAIGraph(docId: document.graph.id.value,
                                            viewPortCenter: document.viewPortCenter,
                                            groupNodeFocused: document.groupNodeFocused?.groupNodeId,
                                            isStreaming: isStreaming)

            // Update topological data--needs to be forced here because of script building using this data
            document.graph.update(from: result.graph)
            document.graph.updateGraphData(document)

            // Report errors
            if !isStreaming {
                result.errors.displayErrors(document: document)
            }
        }

        processLogic()
        
//        if isStreaming {
//            withAnimation(.linear(duration: STREAMING_ANIMATION_SPEED)) {
//                processLogic()
//            }
//        } else {
//            processLogic()
//        }
        
    }
    
    func createAIGraph(docId: UUID,
                       viewPortCenter: CGPoint,
                       groupNodeFocused: UUID?,
                       isStreaming: Bool) -> StitchAIGraphEntityResult {
        // STEP 1: Capture existing state for similarity matching
//        let existingGraph = document.graph.createSchema()
//        let previousSidebarSelection = document.graph.layersSidebarViewModel.primary
//        var matchedNodeIds = Set<UUID>()

        var viewStatePatchConnections = self.graphData.viewStatePatchConnections

        // Instantiate new GraphEntity instance, starting with known patch nodes
        var graphEntity = GraphEntity.createEmpty()
        graphEntity.id = docId
        graphEntity.nodes = self.graphData.patchNodes

        var nodesDict = graphEntity.nodes.reduce(into: [UUID: NodeEntity]()) { result, nodeEntity in
            result.updateValue(nodeEntity, forKey: nodeEntity.id)
        }

        // create nested layer nodes in graph
        // Guard against nil/invalid data during streaming
        if !self.graphData.layer_data_list.isEmpty {
            let (updatedNodes, updatedStateVars) = self.graphData.layer_data_list
                .createLayerNodes(layerGroupId: nil,
                                  nodesDict: nodesDict,
                                  stateVarConnections: viewStatePatchConnections,
                                  isStreaming: isStreaming)

            nodesDict = updatedNodes
            viewStatePatchConnections = updatedStateVars
        }

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
        


        // STEP 3: Restore sidebar selections for matched nodes
        
        // TODO: come back to sidebar selection

        //        document.graph.layersSidebarViewModel.primary = newNodesForSelectedOldNodes
//        log("Restored sidebar selection for \(newNodesForSelectedOldNodes.count) matched nodes")

        return .init(graph: graphEntity,
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
