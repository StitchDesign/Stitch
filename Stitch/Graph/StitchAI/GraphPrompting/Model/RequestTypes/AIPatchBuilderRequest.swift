//
//  AIPatchBuilderRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

//enum AIPatchBuilderRequestError: Error {
//    case nodeIdNotFound
//}

struct AIPatchBuilderRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIPatchBuilderRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         swiftUISourceCode: String,
         layerDataList: [CurrentAIPatchBuilderResponseFormat.LayerData],
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AIPatchBuilderRequestBody(userPrompt: prompt,
                                                  swiftUiSourceCode: swiftUISourceCode,
                                                  layerDataList: layerDataList)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: CurrentAIPatchBuilderResponseFormat.PatchData) throws -> CurrentAIPatchBuilderResponseFormat.PatchData {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: CurrentAIPatchBuilderResponseFormat.PatchData,
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [CurrentAIPatchBuilderResponseFormat.PatchData]) throws -> CurrentAIPatchBuilderResponseFormat.PatchData {
        // Unsupported
        fatalError()
    }
}

extension StitchDocumentViewModel {
    /// Recursively creates new sidebar layer data from AI result after creating nodes.
    @MainActor
    func createLayerNodeFromAI(newLayer: CurrentAIPatchBuilderResponseFormat.LayerData) throws {
        let graph = self.visibleGraph
        
        let migratedNodeName = try newLayer.node_name.value.convert(to: PatchOrLayer.self)
        
        // Creates new layer node view model
        let newLayerNode = graph
            .createNode(graphTime: self.graphStepState.graphTime,
                        newNodeId: newLayer.node_id.value,
                        highestZIndex: graph.highestZIndex,
                        choice: migratedNodeName,
                        center: self.newCanvasItemInsertionLocation)
        graph.visibleNodesViewModel.nodes.updateValue(newLayerNode,
                                                      forKey: newLayerNode.id)
                
        if let children = newLayer.children {
            for child in children {
                // Recursive call
                try self.createLayerNodeFromAI(newLayer: child)
            }
        }
    }
    
    @MainActor
    func updateCustomInputValueFromAI(inputCoordinate: NodeIOCoordinate,
                                      value: CurrentStep.PortValue) throws {
        let graph = self.visibleGraph
        var migratedValue = try value.migrate()
        
        // remap values with UUID
//        switch migratedValue {
//        case .assignedLayer(let layerNodeId):
//            guard let layerNodeId = layerNodeId else {
//                break
//            }
//            
//            guard let newId = idMap[layerNodeId.asNodeId.description] else {
//                fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have layerNodeId \(layerNodeId.asNodeId), idMap: \(idMap)")
//                throw AIPatchBuilderRequestError.nodeIdNotFound
//            }
//            
//            migratedValue = .assignedLayer(.init(newId))
//            
//        case .anchorEntity(let nodeId):
//            guard let nodeId = nodeId else {
//                break
//            }
//            
//            guard let newId = idMap[nodeId.description] else {
//                fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have nodeId \(nodeId), idMap: \(idMap)")
//                throw AIPatchBuilderRequestError.nodeIdNotFound
//            }
//            
//            migratedValue = .anchorEntity(.init(newId))
//
//        default:
//            break
//        }

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

extension CurrentAIPatchBuilderResponseFormat.GraphData {
    @MainActor
    func applyAIGraph(to document: StitchDocumentViewModel) throws {
        let graphEntity = try self.createAIGraph()
        document.visibleGraph
            .insertNewComponent(graphEntity: graphEntity,
                                encoder: document.documentEncoder,
                                copiedFiles: .init(importedMediaUrls: [],
                                                   componentDirs: []),
                                isCopyPaste: false,
                                originGraphOutputValuesMap: .init(),
                                document: document)
        
        document.encodeProjectInBackground()
    }
    
    @MainActor
    func createAIGraph() throws -> GraphEntity {
        let document = StitchDocumentViewModel.createEmpty()
        let graph = document.visibleGraph
        
        // Tracks all patch input coordinates we either make connections or custom vaues for, used for determining if extra rows need to be created
        let allModifiedPatchIds = self.patch_data.custom_patch_input_values.map(\.patch_input_coordinate) + self.patch_data.patch_connections.map(\.dest_port)
        let allModifiedPatchIdsSet = Set(allModifiedPatchIds)
//        assertInDebug(allModifiedPatchIdsSet.count == allModifiedPatchIds.count)
        
        let maxModifiedPortIndex: [UUID : Int] = allModifiedPatchIdsSet.reduce(into: .init()) { result, patchInputId in
            let nodeId = patchInputId.node_id.value
            let existingMaxCount = result.get(nodeId) ?? -1
            result.updateValue(max(patchInputId.port_index + 1, existingMaxCount),
                               forKey: nodeId)
        }
        
        // new js patches
        for newPatch in self.patch_data.javascript_patches {
            let newNode = document.nodeInserted(choice: .patch(.javascript),
                                                nodeId: newPatch.node_id.value)
            
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
            let nodeId = newPatch.node_id.value
            let migratedNodeName = try newPatch.node_name.value.convert(to: PatchOrLayer.self)
            
            let newNode = document.nodeInserted(choice: migratedNodeName,
                                                nodeId: nodeId)
            
            guard let patchNode = newNode.patchNodeViewModel else {
                fatalErrorIfDebug()
                continue
            }
            
            // Set custom value type here
            if let customValueType = self.patch_data.native_patch_value_type_settings.first(where: { $0.node_id.value == nodeId })?.value_type {
                guard let oldType = newNode.userVisibleType else {
                    // TODO: SILENT ERROR
                    log("createAIGraph error: unexpectedly try to change the node type for \(newNode.kind)")
                    continue
                }
                
                let newType = try customValueType.value.migrate()
                let _ = document.graph.changeType(for: newNode,
                                                  oldType: oldType,
                                                  newType: newType,
                                                  activeIndex: document.activeIndex)
            }
            
            // MARK: BEFORE creating edges/inputs, determine if new patch nodes need extra inputs
            let supportsNewInputs = patchNode.patch.canChangeInputCounts
            if let maxModifiedInputIndex = maxModifiedPortIndex.get(nodeId) {
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
            try document.createLayerNodeFromAI(newLayer: newLayer)
        }
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        let newSidebarData = try self.layer_data_list.map { try $0.createSidebarLayerData() }
        
        // Update sidebar view model data with new layer data in beginning
        let oldSidebarList = graph.layersSidebarViewModel.createdOrderedEncodedData()
        let newList = newSidebarData + oldSidebarList
        graph.layersSidebarViewModel.update(from: newList)
        
        // Update graph data so that input observers are created
        graph.updateGraphData(document)
        
        // new constants for patches
        for newInputValueSetting in self.patch_data.custom_patch_input_values {
            let inputCoordinate = NodeIOCoordinate(
                from: newInputValueSetting.patch_input_coordinate)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      value: newInputValueSetting.value)
        }
        
        // new constants for layers
        for newInputValueSetting in self.layer_data_list.allNestedCustomInputValues {
            let inputCoordinate = try NodeIOCoordinate(
                from: newInputValueSetting.layer_input_coordinate)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      value: newInputValueSetting.value)
        }
        
        // new edges to downstream patches
        for newPatchEdge in self.patch_data.patch_connections {
            let inputPort = NodeIOCoordinate(
                from: newPatchEdge.dest_port)
            let outputPort = NodeIOCoordinate(
                from: newPatchEdge.src_port)
            let edge: PortEdgeData = PortEdgeData(
                from: outputPort,
                to: inputPort)
            
            let _ = document.visibleGraph.edgeAdded(edge: edge)
        }
        
        // new edges to downstream layers
        for newLayerEdge in self.patch_data.layer_connections {
            let inputPort = try NodeIOCoordinate(
                from: newLayerEdge.dest_port)
            let outputPort = NodeIOCoordinate(
                from: newLayerEdge.src_port)
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
        
        let graphEntity = document.graph.createSchema()
        return graphEntity
    }
}

extension NodeIOCoordinate {
    init(from aiPatchCoordinate: CurrentAIPatchBuilderResponseFormat.NodeIndexedCoordinate)  {
        self.init(portId: aiPatchCoordinate.port_index,
                  nodeId: aiPatchCoordinate.node_id.value)
    }
    
    init(from aiLayerCoordinate: CurrentAIPatchBuilderResponseFormat.LayerInputCoordinate) throws {
        let portType = Step_V0.NodeIOPortType
            .keyPath(.init(layerInput: aiLayerCoordinate.input_port_type.value,
                           portType: .packed))
        
        let migratedPortType = try portType.convert(to: NodeIOPortType.self)
        
        self.init(portType: migratedPortType,
                  nodeId: aiLayerCoordinate.layer_id.value)
    }
}
