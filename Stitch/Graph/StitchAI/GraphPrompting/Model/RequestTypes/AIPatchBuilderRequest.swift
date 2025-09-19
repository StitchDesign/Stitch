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
    @MainActor
    func createLayerNodes(layerGroupId: UUID?,
                          nodesDict: inout [UUID: NodeEntity],
                          stateVarConnections: inout [String: [NodeIOCoordinate]]) {
        self.forEach { layerData in
            guard let layer = layerData.node_name.value.layer else {
                fatalErrorIfDebug()
                return
            }
            
            let layerNodeEntity = layer
                .createDefaultLayerNodeEntity(nodeId: UUID(layerData.node_id) ?? UUID(),
                                              layerGroupId: layerGroupId)
            
            let nodeEntity = NodeEntity(id: layerNodeEntity.id,
                                        nodeTypeEntity: .layer(layerNodeEntity),
                                        title: layerData.suggested_title ?? "")
            
            nodesDict.updateValue(nodeEntity,
                                  forKey: layerNodeEntity.id)

            layerData.custom_layer_input_values.forEach { portDerivation in
                let coordinate = portDerivation.coordinate
                
                portDerivation.inputData.forEach { inputData in
                    // Parse actions at this input, which may include patch data in the event of view events
                    nodesDict.updateWithEventData(inputData,
                                                  layerInputCoordinate: .init(portType: .keyPath(coordinate),
                                                                              nodeId: layerNodeEntity.id),
                                                  varName: nil,
                                                  stateVarConnections: &stateVarConnections)
                }
            }
            
            
            if let children = layerData.children {
                children
                    .createLayerNodes(layerGroupId: layerNodeEntity.id,
                                      nodesDict: &nodesDict,
                                      stateVarConnections: &stateVarConnections)
            }
        }
    }
}

extension SwiftSyntaxActionsResult {
    @MainActor
    mutating func applyAIGraph(to document: StitchDocumentViewModel,
                               viewStatePatchConnections: [String : [NodeIOCoordinate]]) async {
        // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
        self.createAIGraph(document: document)
        document.encodeProjectInBackground()
    }
    
    @MainActor
    mutating func createAIGraph(document: StitchDocumentViewModel) {
        // STEP 1: Capture existing state for similarity matching
        let existingGraph = document.graph.createSchema()
        let previousSidebarSelection = document.graph.layersSidebarViewModel.primary
        var matchedNodeIds = Set<UUID>()

        var viewStatePatchConnections = self.graphData.viewStatePatchConnections
        
        // STEP 2: Perform comprehensive node similarity matching using extracted pure function
        let matchingInputs = NodeMatchingInputs(
            existingNodes: existingGraph.nodes,
            newPatchNodes: self.graphData.patchNodes,
            newLayerDataList: self.graphData.layer_data_list,
            previousSidebarSelection: previousSidebarSelection
        )

        let matchingResults = performNodeSimilarityMatching(inputs: matchingInputs)

        // Apply results
        let updatedPatchNodes = matchingResults.updatedPatchNodes
        matchedNodeIds = matchingResults.matchedNodeIds
        let layerCanvasItemPositions = matchingResults.layerCanvasItemPositions
        let newNodesForSelectedOldNodes = matchingResults.newNodesForSelectedOldNodes
        let layerIdMapping = matchingResults.layerIdMapping

        // Sync patch graph nodes in document before parsing layers, which may need data from there
        var graphEntity = document.graph.createSchema()
        graphEntity.nodes = updatedPatchNodes

        var nodesDict = graphEntity.nodes.reduce(into: [UUID: NodeEntity]()) { result, nodeEntity in
            result.updateValue(nodeEntity, forKey: nodeEntity.id)
        }

        // create nested layer nodes in graph
        self.graphData.layer_data_list
            .createLayerNodes(layerGroupId: nil,
                              nodesDict: &nodesDict,
                              stateVarConnections: &viewStatePatchConnections)
        
        graphEntity.nodes = Array(nodesDict.values)
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        // Pass the layer ID mapping to preserve matched layer IDs
        let newSidebarData = self.graphData.layer_data_list.compactMap {
            $0.createSidebarLayerData(idMapping: layerIdMapping)
        }
        
        graphEntity.orderedSidebarLayers = newSidebarData
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        let repositionedNodes = graphEntity.nodes.positionAIGeneratedNodesDuringApply(
            viewPortCenter: document.viewPortCenter,
            existingNodes: existingGraph.nodes,
            matchedNodeIds: matchedNodeIds,
            layerCanvasItemPositions: layerCanvasItemPositions)
        graphEntity.nodes = repositionedNodes
        
        // Make group Id map current context
        graphEntity.nodes = graphEntity.nodes.map { nodeEntity in
            var nodeEntity = nodeEntity
            nodeEntity.canvasEntityMutator { canvasEntity in
                var canvasEntity = canvasEntity
                canvasEntity.parentGroupNodeId = document.groupNodeFocused?.groupNodeId
                return canvasEntity
            }
            return nodeEntity
        }
        
        // Update topological data--needs to be forced here because of script building using this data
        document.graph.update(from: graphEntity)
        document.graph.updateGraphData(document)

        // STEP 3: Restore sidebar selections for matched nodes
        document.graph.layersSidebarViewModel.primary = newNodesForSelectedOldNodes
        log("Restored sidebar selection for \(newNodesForSelectedOldNodes.count) matched nodes")

        // Report errors
        caughtErrors.displayErrors(document: document)
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
