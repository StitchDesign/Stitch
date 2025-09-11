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

extension StitchDocumentViewModel {
    /// Recursively creates new sidebar layer data from AI result after creating nodes.
    @MainActor
    func createLayerNodeFromAI(newLayer: CurrentAIGraphData.LayerData,
                               existingGraph: GraphState,
                               idMap: inout [String : UUID]) throws {
        let newId = idMap.get(newLayer.node_id) ?? UUID(newLayer.node_id) ?? UUID()
        idMap.updateValue(newId, forKey: newLayer.node_id)
        idMap.updateValue(newId, forKey: newId.description)
        let graph = self.visibleGraph
        
        let migratedNodeName = try newLayer.node_name.value.convert(to: PatchOrLayer.self)
        let existingLayerNode = existingGraph.nodes.get(newId)
        let needsNewNodeCreation = existingLayerNode?.kind.getLayer != migratedNodeName.layer
        
        if needsNewNodeCreation {
            // Creates new layer node view model
            let newLayerNode = graph
                .createNode(graphTime: self.graphStepState.graphTime,
                            newNodeId: newId,
                            highestZIndex: graph.highestZIndex,
                            choice: migratedNodeName,
                            center: self.newCanvasItemInsertionLocation)
            
            graph.visibleNodesViewModel.nodes.updateValue(newLayerNode,
                                                          forKey: newLayerNode.id)

            // Initialize delegates for later helpers (like edges)
            newLayerNode.initializeDelegate(graph: graph,
                                            document: self)
        }
        
        if let children = newLayer.children {
            for child in children {
                // Recursive call
                try self.createLayerNodeFromAI(newLayer: child,
                                               existingGraph: existingGraph,
                                               idMap: &idMap)
            }
        }
    }
    
    @MainActor
    func updateCustomInputValueFromAI(inputCoordinate: NodeIOCoordinate,
                                      valueType: AIGraphData_V0.NodeType,
                                      data: (any Codable & Sendable),
                                      idMap: inout [String : UUID]) throws {
        guard let inputObserver = graph.getInputObserver(coordinate: inputCoordinate) else {
            log("applyAction: could not apply setInput")
            // fatalErrorIfDebug()
            throw StitchAIStepHandlingError.actionValidationError("Could not retrieve input \(inputCoordinate)")
        }
        
        let graph = self.visibleGraph
        
        let value = try AIGraphData_V0.PortValue.decodeFromAI(data: data,
                                                       valueType: valueType,
                                                       idMap: &idMap)
        let migratedValue = try value.migrate()
        
        // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
        graph.inputEditCommitted(input: inputObserver,
                                 value: migratedValue,
                                 activeIndex: self.activeIndex)
    }
}

extension SwiftSyntaxActionsResult {
    @MainActor
    mutating func applyAIGraph(to document: StitchDocumentViewModel,
                               requestType: StitchAIRequestBuilder_V0.StitchAIRequestType) {
        switch requestType {
        case .userPrompt:
            // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
            self.createAIGraph(document: document)
        }
        
        document.encodeProjectInBackground()
    }
    
    @MainActor
    mutating func createAIGraph(document: StitchDocumentViewModel) {
        guard let aiManager = document.aiManager else {
            return
        }
        
        let graph = document.visibleGraph
        let graphCenter = document.viewPortCenter
        let highestZIndex = document.visibleGraph.highestZIndex
        
        // Track node ID map to create new IDs, fixing ID reusage issue
        // Make sure currently used IDs are tracked so we don't create redundant nodes
        var idMap = graph.nodes.keys.reduce(into: [String : UUID]()) { result, nodeId in
            result.updateValue(nodeId, forKey: nodeId.description)
        }
        
        // Tracks all patch input coordinates we either make connections or custom vaues for, used for determining if extra rows need to be created
//        let allModifiedPatchIds = self.graphData.patch_data.custom_patch_input_values.map(\.patch_input_coordinate) + self.graphData.patch_data.patch_connections.map(\.dest_port)
//        let allModifiedPatchIdsSet = Set(allModifiedPatchIds)
////        assertInDebug(allModifiedPatchIdsSet.count == allModifiedPatchIds.count)
//        
//        let maxModifiedPortIndex: [String : Int] = allModifiedPatchIdsSet.reduce(into: .init()) { result, patchInputId in
//            let nodeId = patchInputId.node_id
//            let existingMaxCount = result.get(nodeId) ?? -1
//            result.updateValue(max(patchInputId.port_index + 1, existingMaxCount),
//                               forKey: nodeId)
//        }
//        
//        // new js patches
//        for newPatch in self.graphData.patch_data.javascript_patches {
//            let newId = idMap.get(newPatch.node_id) ?? UUID()
//            idMap.updateValue(newId, forKey: newPatch.node_id)
//            idMap.updateValue(newId, forKey: newId.description)
//            
//            let newNode = graph.nodes.get(newId) ?? graph
//                .createNode(graphTime: .zero,
//                            newNodeId: newId,
//                            highestZIndex: highestZIndex,
//                            choice: .patch(.javascript),
//                            center: graphCenter)
//            
//            graph.visibleNodesViewModel.nodes.updateValue(newNode, forKey: newId)
//            
//            // Initialize delegates for later helpers (like edges)
//            newNode.initializeDelegate(graph: graph,
//                                       document: document)
//            
//            if let patchNode = newNode.patchNode {
//                // Get AI info
//                let jsNodeRequest = AIJSNodeSettingsFromScritptRequest(existingScript: newPatch.sourceCode)
//                
//                do {
//                    let jsSettings = try await jsNodeRequest
//                        .request(document: document,
//                                 aiManager: aiManager)
//                    
//                    patchNode.processNewJavascript(response: jsSettings,
//                                                   document: document)
//                } catch let error as SwiftUISyntaxError {
//                    caughtErrors.append(error)
//                } catch {
//                    fatalErrorIfDebug(error.localizedDescription)
//                }
//                
//                // Check here
//                assertInDebug(patchNode.javaScriptNodeSettings != nil)
//            }
//        }
//        
//        // new native patches
//        for newPatch in self.graphData.patch_data.native_patches {
//            let oldId = newPatch.node_id
//            let newId = idMap.get(oldId) ?? UUID()
//            idMap.updateValue(newId, forKey: oldId)
//            idMap.updateValue(newId, forKey: newId.description)
//            
//            guard let migratedNodeName = try? newPatch.node_name.value.convert(to: PatchOrLayer.self) else {
//                fatalErrorIfDebug("createAIGraph error: could not migrate patch name of \(newPatch.node_name.value)")
//                continue
//            }
//            
//            let existingPatchNode = graph.nodes.get(newId)
//            let needsNewNodeCreation = existingPatchNode?.patch != migratedNodeName.patch
//            let newNode: NodeViewModel
//            
//            if needsNewNodeCreation {
//                newNode = graph.nodes.get(newId) ?? graph
//                    .createNode(graphTime: .zero,
//                                newNodeId: newId,
//                                highestZIndex: highestZIndex,
//                                choice: migratedNodeName,
//                                center: graphCenter)
//                
//                graph.visibleNodesViewModel.nodes.updateValue(newNode, forKey: newId)
//                
//                // Initialize delegates for later helpers (like edges)
//                newNode.initializeDelegate(graph: graph,
//                                           document: document)
//            }
//        }
        
//        // Set input values for new nodes
//        for (oldId, newId) in idMap {
//            guard let newNode = graph.nodes.get(newId) else {
//                fatalErrorIfDebug()
//                continue
//            }
//            
//            // Set custom value type here
//            if let customValueType = self.graphData.patch_data.native_patch_value_type_settings.first(where: { $0.node_id == oldId })?.value_type,
//               let oldType = newNode.userVisibleType {
//                guard let newType = try? customValueType.value.migrate() else {
//                    fatalErrorIfDebug("createAIGraph error: could not migrate value type of \(customValueType.value)")
//                    continue
//                }
//                
//                let _ = document.graph.changeType(for: newNode,
//                                                  oldType: oldType,
//                                                  newType: newType,
//                                                  activeIndex: document.activeIndex,
//                                                  graphTime: document.graphStepState.graphTime)
//            }
//            
//            // MARK: BEFORE creating edges/inputs, determine if new patch nodes need extra inputs
//            if let patchNode = newNode.patchNodeViewModel {
//                let supportsNewInputs = patchNode.patch.canChangeInputCounts
//                if let maxModifiedInputIndex = maxModifiedPortIndex.get(oldId) {
//                    let missingRowCount = maxModifiedInputIndex - patchNode.inputsObservers.count
//                    
//                    if missingRowCount > 0 {
//                        guard supportsNewInputs else {
//                            caughtErrors.append(
//                                SwiftUISyntaxError.unexpectedPatchInputRowCount(patchNode.patch)
//                            )
//                            
//                            continue
//                        }
//                        
//                        for _ in (0..<missingRowCount) {
//                            newNode.addInputObserver(graph: document.graph,
//                                                     document: document)
//                        }
//                    }
//                }                
//            }
//        }
        
        // create nested layer nodes in graph
        for newLayer in self.graphData.layer_data_list {
            do {
                // Recursive caller
                try document.createLayerNodeFromAI(newLayer: newLayer,
                                                   existingGraph: graph,
                                                   idMap: &idMap)
            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
        }
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        let newSidebarData = self.graphData.layer_data_list.compactMap {
            do {
                return try $0.createSidebarLayerData(idMap: idMap)
            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
            
            return nil
        }
        
        // Update sidebar view model data with new layer data
        graph.layersSidebarViewModel.update(from: newSidebarData)
        
        // new constants for patches
//        for newInputValueSetting in self.graphData.patch_data.custom_patch_input_values {
//            do {
//                let inputCoordinate = try NodeIOCoordinate(
//                    from: newInputValueSetting.patch_input_coordinate,
//                    idMap: idMap)
//                try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
//                                                          valueType: newInputValueSetting.value_type.value,
//                                                          data: newInputValueSetting.value,
//                                                          idMap: &idMap)
//            } catch let error as SwiftUISyntaxError {
//                caughtErrors.append(error)
//            } catch {
//                fatalErrorIfDebug(error.localizedDescription)
//            }
//        }
        
        // new state for layers
        self.graphData.layer_data_list.allNestedCustomInputValues { layerNodeId, newInputValueSetting in
            do {
                let inputCoordinate = try NodeIOCoordinate(
                    from: .init(layer_id: layerNodeId,
                                input_port_type: newInputValueSetting.coordinate),
                    idMap: idMap)
                
                switch newInputValueSetting.inputData {
                case .value(let value):
                    try document
                        .updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      valueType: value.value_type.value,
                                                      data: value.value,
                                                      idMap: &idMap)
                    
                case .stateRef(let varName):
                    // Get upstream patch data from variable name
                    guard let upstreamPatchCoordinate = self.graphData.viewStatePatchConnections
                        .get(varName) else {
                        //                    fatalErrorIfDebug()
                        return
                    }
                    
                    let newEdgeData = PortEdgeData(from: .init(portId: upstreamPatchCoordinate.portId!,
                                                               nodeId: upstreamPatchCoordinate.nodeId),
                                                   to: inputCoordinate)
                    
                    // create canvas node
                    guard let node = graph.getNode(upstreamPatchCoordinate.nodeId),
                          let fromNodeLocation = node.nonLayerCanvasItem?.position,
                          let destinationNode = document.visibleGraph.getNode(inputCoordinate.nodeId),
                          let layerInputType = inputCoordinate.keyPath else {
                        throw SwiftUISyntaxError.layerEdgeDataFailure(varName)
                    }
                    
                    var position = fromNodeLocation
                    position.x += 200
                    
                    document.addCanvasLayerInput(node: destinationNode,
                                                 layerInputType: layerInputType,
                                                 draggedOutput: nil,
                                                 canvasHeightOffset: nil,
                                                 position: position)
                    
                    graph.addEdgeWithoutGraphRecalc(edge: newEdgeData)
                }
            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
        }
        
        // new edges to downstream patches
//        for newPatchEdge in self.graphData.patch_data.patch_connections {
//            do {
//                let inputPort = try NodeIOCoordinate(
//                    from: newPatchEdge.dest_port,
//                    idMap: idMap)
//                let outputPort = try NodeIOCoordinate(
//                    from: newPatchEdge.src_port,
//                    idMap: idMap)
//                let edge: PortEdgeData = PortEdgeData(
//                    from: outputPort,
//                    to: inputPort)
//                
//                let _ = document.visibleGraph.addEdgeWithoutGraphRecalc(edge: edge)
//            } catch let error as SwiftUISyntaxError {
//                caughtErrors.append(error)
//            } catch {
//                fatalErrorIfDebug(error.localizedDescription)
//            }
//        }
        
        // Delete unused nodes
//        let allNewIds = self.graphData.patch_data.javascript_patches.map(\.node_id) +
//        self.graphData.patch_data.native_patches.map(\.node_id) +
//        self.graphData.layer_data_list.allFlattenedItems.map(\.node_id)
//        
//        let allNewMappedIds = allNewIds.compactMap { idMap.get($0) }
//        let nodeIdsToDelete = Set(document.visibleGraph.nodes.keys).subtracting(allNewMappedIds)
//
//        for nodeIdToDelete in nodeIdsToDelete {
//            document.visibleGraph.deleteNode(id: nodeIdToDelete,
//                                             document: document)
//        }
        
        var graphEntity = document.graph.createSchema()
        let allNodes = self.graphData.patchNodes + graphEntity.nodes
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        let repositionedNodes = allNodes.positionAIGeneratedNodesDuringApply(
            viewPortCenter: document.viewPortCenter,
            graph: document.visibleGraph)
        graphEntity.nodes = repositionedNodes
        
        // Update topological data--needs to be forced here because of script building using this data
        document.graph.update(from: graphEntity)
        document.graph.updateGraphData(document)
        
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
