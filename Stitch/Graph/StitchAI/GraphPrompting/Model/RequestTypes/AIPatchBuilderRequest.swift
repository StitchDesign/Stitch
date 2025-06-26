//
//  AIPatchBuilderRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AIPatchBuilderRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIPatchBuilderRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         jsSourceCode: String,
         layerList: SidebarLayerList,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AIPatchBuilderRequestBody(userPrompt: prompt,
                                                  swiftUiSourceCode: jsSourceCode,
                                                  layerList: layerList)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: CurrentAIPatchBuilderResponseFormat.GraphData) throws -> CurrentAIPatchBuilderResponseFormat.GraphData {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: CurrentAIPatchBuilderResponseFormat.GraphData,
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [CurrentAIPatchBuilderResponseFormat.GraphData]) throws -> CurrentAIPatchBuilderResponseFormat.GraphData {
        // Unsupported
        fatalError()
    }
}

extension StitchDocumentViewModel {
    /// Recursively creates new sidebar layer data from AI result after creating nodes.
    @MainActor
    func createLayerNodeFromAI(newLayer: CurrentAIPatchBuilderResponseFormat.LayerNode) throws -> SidebarLayerData {
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
        
        var sidebarData = SidebarLayerData(id: newLayerNode.id)
        
        if let children = newLayer.children {
            var sidebarChildrenData = [SidebarLayerData]()
            for child in children {
                // Recursive call
                let newChildLayerData = try self.createLayerNodeFromAI(newLayer: child)
                sidebarChildrenData.append(newChildLayerData)
            }
            
            sidebarData.children = sidebarChildrenData
        }
        
        return sidebarData
    }
}

extension CurrentAIPatchBuilderResponseFormat.GraphData {
    @MainActor
    func apply(to document: StitchDocumentViewModel) throws {
        let graph = document.visibleGraph
        
        // new js patches
        for newPatch in self.javascript_patches {
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
        for newPatch in self.native_patches {
            let migratedNodeName = try newPatch.node_name.value.convert(to: PatchOrLayer.self)
            
            let _ = document.nodeInserted(choice: migratedNodeName,
                                          nodeId: newPatch.node_id.value)
        }
        
        // new layer nodes
        var newLayerSidebarDataList = [SidebarLayerData]()
        for newLayer in self.layers {
            let newSidebarData = try document.createLayerNodeFromAI(newLayer: newLayer)
            newLayerSidebarDataList.append(newSidebarData)
        }
        
        // Update sidebar view model data with new layer data in beginning
        let oldSidebarList = graph.layersSidebarViewModel.createdOrderedEncodedData()
        let newList = newLayerSidebarDataList + oldSidebarList
        graph.layersSidebarViewModel.update(from: newList)
        
        // Update graph data so that input observers are created
        graph.updateGraphData(document)
        
        // new constants
        for newInputValueSetting in self.custom_patch_input_values {
            let inputCoordinate = NodeIOCoordinate(from: newInputValueSetting.patch_input_coordinate)
            let migratedValue = try newInputValueSetting.value.migrate()
            
            guard let input = graph.getInputObserver(coordinate: inputCoordinate) else {
                log("applyAction: could not apply setInput")
                // fatalErrorIfDebug()
                throw StitchAIStepHandlingError.actionValidationError("Could not retrieve input \(inputCoordinate)")
            }
            
            // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
            graph.inputEditCommitted(input: input,
                                     value: migratedValue,
                                     activeIndex: document.activeIndex)
        }
        
        // new edges to downstream patches
        for newPatchEdge in self.patch_connections {
            let inputPort = NodeIOCoordinate(from: newPatchEdge.dest_port)
            let outputPort = NodeIOCoordinate(from: newPatchEdge.src_port)
            let edge: PortEdgeData = PortEdgeData(
                from: outputPort,
                to: inputPort)
            
            let _ = document.visibleGraph.edgeAdded(edge: edge)
        }
        
        // new edges to downstream layers
        for newLayerEdge in self.layer_connections {
            let inputPort = try NodeIOCoordinate(from: newLayerEdge.dest_port)
            let outputPort = NodeIOCoordinate(from: newLayerEdge.src_port)
            let edge: PortEdgeData = PortEdgeData(
                from: outputPort,
                to: inputPort)
            
            guard let fromNodeLocation = document.visibleGraph.getNode(outputPort.nodeId)?.nonLayerCanvasItem?.position,
                  let destinationNode = document.visibleGraph.getNode(inputPort.nodeId),
                  let layerInput = inputPort.keyPath?.layerInput else {
                fatalErrorIfDebug()
                return
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
        
        document.encodeProjectInBackground()
    }
}

extension NodeIOCoordinate {
    init(from aiPatchCoordinate: CurrentAIPatchBuilderResponseFormat.NodeIndexedCoordinate) {
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
