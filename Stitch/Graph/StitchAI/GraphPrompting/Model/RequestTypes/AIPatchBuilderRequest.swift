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
                          stateVarConnections: inout [String: NodeIOCoordinate]) {
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
                               viewStatePatchConnections: [String : NodeIOCoordinate]) async {
        // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
        self.createAIGraph(document: document)
        document.encodeProjectInBackground()
    }
    
    @MainActor
    mutating func createAIGraph(document: StitchDocumentViewModel) {
        // STEP 1: Capture existing state for similarity matching
        let existingGraph = document.graph.createSchema()
        let matcher = NodeEntitySimilarityMatcher(oldNodes: existingGraph.nodes)
        let previousSidebarSelection = document.graph.layersSidebarViewModel.primary
        var matchedNodeIds = Set<UUID>()

        var viewStatePatchConnections = self.graphData.viewStatePatchConnections
        
        // STEP 2: Apply similarity matching to patch nodes using one-to-one batch matching
        // We keep the new AI nodes but preserve positions from matched existing nodes

        // Prepare new patch nodes for batch matching
        let newPatchNodeData: [(UUID, PatchOrLayer)] = self.graphData.patchNodes.compactMap { currentPatch in
            if case .patch(let patchNodeEntity) = currentPatch.nodeTypeEntity {
                return (currentPatch.id, PatchOrLayer.patch(patchNodeEntity.patch))
            }
            return nil
        }

        // Perform optimal one-to-one matching
        let optimalMatches = matcher.findOptimalMatches(for: newPatchNodeData)
        log("Found \(optimalMatches.count) optimal matches for \(newPatchNodeData.count) new patch nodes")

        // Process the matches to build position mappings and selection mappings
        var nodePositionMappings: [UUID: CGPoint] = [:]  // new node ID -> old position
        var newNodesForSelectedOldNodes = Set<UUID>()  // new node IDs that should be selected

        for match in optimalMatches {
            // Only accept matches with high similarity scores
            if match.similarity > PATCH_MATCHING_SIMILARITY_THRESHOLD {
                // Store the position mapping: new node should use old node's position
                if case .patch(let matchedPatchEntity) = match.oldNode.nodeTypeEntity {
                    nodePositionMappings[match.newNodeId] = matchedPatchEntity.canvasEntity.position
                    matchedNodeIds.insert(match.newNodeId)  // Track the NEW node ID

                    // If the old node was selected, mark the new node for selection
                    if previousSidebarSelection.contains(match.oldNode.id) {
                        newNodesForSelectedOldNodes.insert(match.newNodeId)
                    }

                    log("Matched new patch node \(match.newNodeId) (\(match.newNodeType)) with existing \(match.oldNode.id) (\(match.oldNode.kind)), similarity \(match.similarity)")
                }
            }
        }

        // Apply preserved positions to matched patch nodes
        var updatedPatchNodes = self.graphData.patchNodes
        for i in 0..<updatedPatchNodes.count {
            let nodeId = updatedPatchNodes[i].id
            if let preservedPosition = nodePositionMappings[nodeId],
               case .patch(var patchNodeEntity) = updatedPatchNodes[i].nodeTypeEntity {
                patchNodeEntity.canvasEntity.position = preservedPosition
                updatedPatchNodes[i].nodeTypeEntity = .patch(patchNodeEntity)
                log("Applied preserved position \(preservedPosition) to node \(nodeId)")
            }
        }

        // STEP 2.5: Apply similarity matching to layer nodes using one-to-one batch matching
        // Extract new layer data for matching before creating them
        let newLayerNodeData: [(UUID, PatchOrLayer)] = self.graphData.layer_data_list.flatMap { layerData -> [(UUID, PatchOrLayer)] in
            // Recursive function to extract all layer data including nested children
            func extractLayerData(from data: AIGraphData_V0.LayerData) -> [(UUID, PatchOrLayer)] {
                var results: [(UUID, PatchOrLayer)] = []

                // Add current layer
                if let layer = data.node_name.value.layer {
                    let layerId = UUID(data.node_id) ?? UUID()
                    results.append((layerId, PatchOrLayer.layer(layer)))
                }

                // Recursively add children
                if let children = data.children {
                    for child in children {
                        results.append(contentsOf: extractLayerData(from: child))
                    }
                }

                return results
            }

            return extractLayerData(from: layerData)
        }

        // Perform optimal one-to-one matching for layers
        let optimalLayerMatches = matcher.findOptimalMatches(for: newLayerNodeData)
        log("Found \(optimalLayerMatches.count) optimal layer matches for \(newLayerNodeData.count) new layer nodes")

        // Process layer matches to build position mappings and selection mappings
        var layerSidebarSelections = Set<UUID>()  // new layer IDs that should be selected
        var layerCanvasItemPositions: [LayerCanvasItemCoordinate: CGPoint] = [:]

        for match in optimalLayerMatches {
            // Only accept matches with reasonable similarity scores
            if match.similarity > LAYER_MATCHING_SIMILARITY_THRESHOLD {
                // Store the position mapping: new layer should use old layer's position
                if case .layer(let matchedLayerEntity) = match.oldNode.nodeTypeEntity {
                    log("📍 Capturing canvas positions for matched layer \(match.oldNode.id) -> \(match.newNodeId)")

                    // Capture canvas item positions using pure function
                    let capturedPositions = captureLayerCanvasItemPositions(
                        from: matchedLayerEntity,
                        forNewNodeId: match.newNodeId
                    )
                    layerCanvasItemPositions.merge(capturedPositions) { _, new in new }

                    matchedNodeIds.insert(match.newNodeId)  // Track the NEW layer ID for position skipping

                    log("📍 Total preserved positions for layer: \(capturedPositions.count)")

                    // If the old layer was selected, mark the new layer for selection
                    if previousSidebarSelection.contains(match.oldNode.id) {
                        layerSidebarSelections.insert(match.newNodeId)
                    }

                    log("Matched new layer node \(match.newNodeId) (\(match.newNodeType)) with existing \(match.oldNode.id) (\(match.oldNode.kind)), similarity \(match.similarity)")
                }
            }
        }

        // Add layer selections to the overall selection set
        newNodesForSelectedOldNodes.formUnion(layerSidebarSelections)

        // Build ID mapping for sidebar creation: AI node_id -> matched UUID
        var layerIdMapping: [String: UUID] = [:]

        // Helper function to recursively find AI node_id for a given UUID
        func findLayerNodeId(in layerDataList: [AIGraphData_V0.LayerData], targetUUID: UUID, callback: (String) -> Void) {
            for layerData in layerDataList {
                if UUID(layerData.node_id) == targetUUID {
                    callback(layerData.node_id)
                    return
                }
                if let children = layerData.children {
                    findLayerNodeId(in: children, targetUUID: targetUUID, callback: callback)
                }
            }
        }

        for match in optimalLayerMatches {
            if match.similarity > LAYER_MATCHING_SIMILARITY_THRESHOLD {
                // Find the AI node_id string that corresponds to this matched UUID
                findLayerNodeId(in: self.graphData.layer_data_list, targetUUID: match.newNodeId) { nodeId in
                    layerIdMapping[nodeId] = match.newNodeId
                }
            }
        }

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
            graph: document.visibleGraph,
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
