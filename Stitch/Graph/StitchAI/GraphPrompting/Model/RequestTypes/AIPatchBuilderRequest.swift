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

struct AIPatchBuilderRequest: StitchAIFunctionRequestable {
    static let aiService: AIServiceType = .openAI
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIPatchBuilderRequestBody
    static let willStream: Bool = false
    
    init(id: UUID,
         userPrompt: String,
         layerDataList: [CurrentAIGraphData.LayerData],
         toolMessages: [OpenAIMessage],
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         systemPrompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = id
        
        self.userPrompt = userPrompt
        self.config = config
        
        // Construct http payload
        self.body = try AIPatchBuilderRequestBody(userPrompt: userPrompt,
                                                  layerDataList: layerDataList,
                                                  toolMessages: toolMessages,
                                                  requestType: requestType,
                                                  systemPrompt: systemPrompt)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: [OpenAIToolCallResponse]) throws -> [OpenAIToolCallResponse] {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: [OpenAIToolCallResponse],
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [[OpenAIToolCallResponse]]) throws -> [OpenAIToolCallResponse] {
        // Unsupported
        fatalError()
    }
}

extension StitchDocumentViewModel {
    /// Recursively creates new sidebar layer data from AI result after creating nodes.
    @MainActor
    func createLayerNodeFromAI(newLayer: CurrentAIGraphData.LayerData,
                               existingGraph: GraphState,
                               idMap: inout [String : UUID]) throws {
        let newId = idMap.get(newLayer.node_id) ?? UUID()
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
        let graph = self.visibleGraph
        
        let value = try AIGraphData_V0.PortValue.decodeFromAI(data: data,
                                                       valueType: valueType,
                                                       idMap: &idMap)
        let migratedValue = try value.migrate()

        guard let input = graph.getInputObserver(coordinate: inputCoordinate) else {
            log("applyAction: could not apply setInput")
            // fatalErrorIfDebug()
            throw StitchAIStepHandlingError.actionValidationError("Could not retrieve input \(inputCoordinate)")
        }
        
        // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
        graph.inputEditCommitted(input: input,
                                 value: migratedValue,
                                 activeIndex: self.activeIndex)
    }
}

extension CurrentAIGraphData.GraphData {
    @MainActor
    func applyAIGraph(to document: StitchDocumentViewModel,
                      requestType: StitchAIRequestBuilder_V0.StitchAIRequestType) throws {
        switch requestType {
        case .userPrompt:
            // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
            try self.createAIGraph(graphCenter: document.viewPortCenter,
                                   highestZIndex: document.visibleGraph.highestZIndex,
                                   document: document)
            
        case .imagePrompt:
            // Image upload-based requests are assumed to provide supplementary graph data, rather than full-on replacements. We create a mock document view model and then use copy-paste logic for support.
            let mockDocumentViewModel = StitchDocumentViewModel.createEmpty()
            try self.createAIGraph(graphCenter: document.viewPortCenter,
                                   highestZIndex: document.visibleGraph.highestZIndex,
                                   document: mockDocumentViewModel)
            let graphEntity = mockDocumentViewModel.visibleGraph.createSchema()
            
            document.visibleGraph
                .insertNewComponent(graphEntity: graphEntity,
                                    encoder: document.documentEncoder,
                                    copiedFiles: .init(importedMediaUrls: [],
                                                       componentDirs: []),
                                    isCopyPaste: false,
                                    originGraphOutputValuesMap: .init(),
                                    document: document)
        }
        
        document.encodeProjectInBackground()
    }
    
    @MainActor
    func createAIGraph(graphCenter: CGPoint,
                       highestZIndex: Double,
                       document: StitchDocumentViewModel) throws {
        let graph = document.visibleGraph
        
        // Track node ID map to create new IDs, fixing ID reusage issue
        // Make sure currently used IDs are tracked so we don't create redundant nodes
        var idMap = graph.nodes.keys.reduce(into: [String : UUID]()) { result, nodeId in
            result.updateValue(nodeId, forKey: nodeId.description)
        }
        
        // Tracks all patch input coordinates we either make connections or custom vaues for, used for determining if extra rows need to be created
        let allModifiedPatchIds = self.patch_data.custom_patch_input_values.map(\.patch_input_coordinate) + self.patch_data.patch_connections.map(\.dest_port)
        let allModifiedPatchIdsSet = Set(allModifiedPatchIds)
//        assertInDebug(allModifiedPatchIdsSet.count == allModifiedPatchIds.count)
        
        let maxModifiedPortIndex: [String : Int] = allModifiedPatchIdsSet.reduce(into: .init()) { result, patchInputId in
            let nodeId = patchInputId.node_id
            let existingMaxCount = result.get(nodeId) ?? -1
            result.updateValue(max(patchInputId.port_index + 1, existingMaxCount),
                               forKey: nodeId)
        }
        
        // new js patches
        for newPatch in self.patch_data.javascript_patches {
            let newId = idMap.get(newPatch.node_id) ?? UUID()
            idMap.updateValue(newId, forKey: newPatch.node_id)
            idMap.updateValue(newId, forKey: newId.description)
            
            let newNode = graph.nodes.get(newId) ?? graph
                .createNode(graphTime: .zero,
                            newNodeId: newId,
                            highestZIndex: highestZIndex,
                            choice: .patch(.javascript),
                            center: graphCenter)

            graph.visibleNodesViewModel.nodes.updateValue(newNode, forKey: newId)
            
            if let patchNode = newNode.patchNode {
                let jsSettings = try JavaScriptNodeSettings(
                    suggestedTitle: newPatch.suggested_title,
                    script: newPatch.javascript_source_code,
                    inputDefinitions: newPatch.input_definitions.map(JavaScriptPortDefinition.init),
                    outputDefinitions: newPatch.output_definitions.map(JavaScriptPortDefinition.init))
                
                patchNode.processNewJavascript(response: jsSettings,
                                               document: document)
            }
        }
        
        // new native patches
        for newPatch in self.patch_data.native_patches {
            let oldId = newPatch.node_id
            let newId = idMap.get(oldId) ?? UUID()
            idMap.updateValue(newId, forKey: oldId)
            idMap.updateValue(newId, forKey: newId.description)
            
            let migratedNodeName = try newPatch.node_name.value.convert(to: PatchOrLayer.self)
            let existingPatchNode = graph.nodes.get(newId)
            let needsNewNodeCreation = existingPatchNode?.patch != migratedNodeName.patch
            let newNode: NodeViewModel
            
            if needsNewNodeCreation {
                newNode = graph.nodes.get(newId) ?? graph
                    .createNode(graphTime: .zero,
                                newNodeId: newId,
                                highestZIndex: highestZIndex,
                                choice: migratedNodeName,
                                center: graphCenter)
                
                graph.visibleNodesViewModel.nodes.updateValue(newNode, forKey: newId)
            } else if let existingPatchNode = existingPatchNode {
                newNode = existingPatchNode
            } else {
                fatalErrorIfDebug()
                continue
            }
            
            guard let patchNode = newNode.patchNodeViewModel else {
                fatalErrorIfDebug()
                continue
            }
            
            // Set custom value type here
            if let customValueType = self.patch_data.native_patch_value_type_settings.first(where: { $0.node_id == oldId })?.value_type,
               let oldType = newNode.userVisibleType {
                let newType = try customValueType.value.migrate()
                let _ = document.graph.changeType(for: newNode,
                                                  oldType: oldType,
                                                  newType: newType,
                                                  activeIndex: document.activeIndex,
                                                  graphTime: document.graphStepState.graphTime)
            }
            
            // MARK: BEFORE creating edges/inputs, determine if new patch nodes need extra inputs
            let supportsNewInputs = patchNode.patch.canChangeInputCounts
            if let maxModifiedInputIndex = maxModifiedPortIndex.get(oldId) {
                let missingRowCount = maxModifiedInputIndex - patchNode.inputsObservers.count

                if missingRowCount > 0 {
                    guard supportsNewInputs else {
                        throw SwiftUISyntaxError.unexpectedPatchInputRowCount(patchNode.patch)
                    }
                    
                    for _ in (0..<missingRowCount) {
                        newNode.addInputObserver(graph: document.graph,
                                                 document: document)
                    }
                }
            }
        }
        
        // create nested layer nodes in graph
        for newLayer in self.layer_data_list {
            // Recursive caller
            try document.createLayerNodeFromAI(newLayer: newLayer,
                                               existingGraph: graph,
                                               idMap: &idMap)
        }
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        let newSidebarData = try self.layer_data_list.map { try $0.createSidebarLayerData(idMap: idMap) }
        
        // Update sidebar view model data with new layer data
        graph.layersSidebarViewModel.update(from: newSidebarData)
        
        // Update graph data so that input observers are created
        graph.updateGraphData(document)
        
        // new constants for patches
        for newInputValueSetting in self.patch_data.custom_patch_input_values {
            let inputCoordinate = try NodeIOCoordinate(
                from: newInputValueSetting.patch_input_coordinate,
                idMap: idMap)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      valueType: newInputValueSetting.value_type.value,
                                                      data: newInputValueSetting.value,
                                                      idMap: &idMap)
        }
        
        // new constants for layers
        for newInputValueSetting in self.layer_data_list.allNestedCustomInputValues {
            let inputCoordinate = try NodeIOCoordinate(
                from: newInputValueSetting.layer_input_coordinate,
                idMap: idMap)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      valueType: newInputValueSetting.value_type.value,
                                                      data: newInputValueSetting.value,
                                                      idMap: &idMap)
        }
        
        // new edges to downstream patches
        for newPatchEdge in self.patch_data.patch_connections {
            let inputPort = try NodeIOCoordinate(
                from: newPatchEdge.dest_port,
                idMap: idMap)
            let outputPort = try NodeIOCoordinate(
                from: newPatchEdge.src_port,
                idMap: idMap)
            let edge: PortEdgeData = PortEdgeData(
                from: outputPort,
                to: inputPort)
            
            let _ = document.visibleGraph.edgeAdded(edge: edge)
        }
        
        // new edges to downstream layers
        for newLayerEdge in self.patch_data.layer_connections {
            let inputPort = try NodeIOCoordinate(
                from: newLayerEdge.dest_port,
                idMap: idMap)
            let outputPort = try NodeIOCoordinate(
                from: newLayerEdge.src_port,
                idMap: idMap)
            let edge: PortEdgeData = PortEdgeData(
                from: outputPort,
                to: inputPort)
            
            guard let fromNodeLocation = document.visibleGraph.getNode(outputPort.nodeId)?.nonLayerCanvasItem?.position,
                  let destinationNode = document.visibleGraph.getNode(inputPort.nodeId),
                  let layerInput = inputPort.keyPath?.layerInput else {
                throw SwiftUISyntaxError.layerEdgeDataFailure(newLayerEdge)
            }

            // create canvas node
            var position = fromNodeLocation
            position.x += 200
            
            document.addLayerInputToCanvas(node: destinationNode,
                                           layerInput: layerInput,
                                           draggedOutput: nil,
                                           canvasHeightOffset: nil,
                                           position: position)
            
            let _ = document.visibleGraph.edgeAdded(edge: edge)
        }
        
        // Delete unused nodes
        let allNewIds = self.patch_data.javascript_patches.map(\.node_id) +
        self.patch_data.native_patches.map(\.node_id) +
        self.layer_data_list.allFlattenedItems.map(\.node_id)
        
        let allNewMappedIds = allNewIds.compactMap { idMap.get($0) }
        let nodeIdsToDelete = Set(document.visibleGraph.nodes.keys).subtracting(allNewMappedIds)

        for nodeIdToDelete in nodeIdsToDelete {
            document.visibleGraph.deleteNode(id: nodeIdToDelete,
                                             document: document)
        }
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        positionAIGeneratedNodesDuringApply(
            nodes: document.visibleGraph.visibleNodesViewModel,
            viewPortCenter: document.viewPortCenter,
            graph: document.visibleGraph)
    }
}

extension NodeIOCoordinate {
    init(from aiPatchCoordinate: CurrentAIGraphData.NodeIndexedCoordinate,
         idMap: [String : UUID]) throws {
        guard let newId = idMap.get(aiPatchCoordinate.node_id) else {
            log("updateCustomInputValueFromAI: idMap did not have aiPatchCoordinate.node_id \(aiPatchCoordinate.node_id), idMap: \(idMap)")
            throw AIPatchBuilderRequestError.nodeIdNotFound
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
            .keyPath(.init(layerInput: aiLayerCoordinate.input_port_type.value,
                           portType: .packed))
        
        let migratedPortType = try portType.convert(to: NodeIOPortType.self)
        
        self.init(portType: migratedPortType,
                  nodeId: newId)
    }
}
