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

struct AIPatchBuilderRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIPatchBuilderRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         swiftUISourceCode: String,
         layerData: CurrentAIPatchBuilderResponseFormat.LayerData,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AIPatchBuilderRequestBody(userPrompt: prompt,
                                                  swiftUiSourceCode: swiftUISourceCode,
                                                  layerData: layerData)
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
    func createLayerNodeFromAI(newLayer: CurrentAIPatchBuilderResponseFormat.LayerNode,
                               idMap: inout [UUID : UUID]) throws -> SidebarLayerData {
        let newId = UUID()
        idMap.updateValue(newId, forKey: newLayer.node_id.value)
        let graph = self.visibleGraph
        
        let migratedNodeName = try newLayer.node_name.value.convert(to: PatchOrLayer.self)
        
        // Creates new layer node view model
        let newLayerNode = graph
            .createNode(graphTime: self.graphStepState.graphTime,
                        newNodeId: newId,
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
                let newChildLayerData = try self.createLayerNodeFromAI(newLayer: child,
                                                                       idMap: &idMap)
                sidebarChildrenData.append(newChildLayerData)
            }
            
            sidebarData.children = sidebarChildrenData
        }
        
        return sidebarData
    }
    
    @MainActor
    func updateCustomInputValueFromAI(inputCoordinate: NodeIOCoordinate,
                                      value: CurrentStep.PortValue,
                                      idMap: [UUID : UUID]) throws {
        let graph = self.visibleGraph
        var migratedValue = try value.migrate()
        
        // remap values with UUID
        switch migratedValue {
        case .assignedLayer(let layerNodeId):
            guard let layerNodeId = layerNodeId else {
                break
            }
            
            guard let newId = idMap[layerNodeId.asNodeId] else {
                fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have layerNodeId \(layerNodeId.asNodeId), idMap: \(idMap)")
                throw AIPatchBuilderRequestError.nodeIdNotFound
            }
            
            migratedValue = .assignedLayer(.init(newId))
            
        case .anchorEntity(let nodeId):
            guard let nodeId = nodeId else {
                break
            }
            
            guard let newId = idMap[nodeId] else {
                fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have nodeId \(nodeId), idMap: \(idMap)")
                throw AIPatchBuilderRequestError.nodeIdNotFound
            }
            
            migratedValue = .anchorEntity(.init(newId))

        default:
            break
        }

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
        let graph = document.visibleGraph
        
        // Track node ID map to create new IDs, fixing ID reusage issue
        var idMap = [UUID : UUID]()
        
        // new js patches
        for newPatch in self.patch_data.javascript_patches {
            let newId = UUID()
            idMap.updateValue(newId, forKey: newPatch.node_id.value)
            let newNode = document.nodeInserted(choice: .patch(.javascript),
                                                nodeId: newId)
            
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
            let newId = UUID()
            idMap.updateValue(newId, forKey: newPatch.node_id.value)
            let migratedNodeName = try newPatch.node_name.value.convert(to: PatchOrLayer.self)
            
            let _ = document.nodeInserted(choice: migratedNodeName,
                                          nodeId: newId)
        }
        
        // new layer nodes
        var newLayerSidebarDataList = [SidebarLayerData]()
        for newLayer in self.layer_data.layers {
            let newSidebarData = try document.createLayerNodeFromAI(newLayer: newLayer,
                                                                    idMap: &idMap)
            newLayerSidebarDataList.append(newSidebarData)
        }
        
        // Update sidebar view model data with new layer data in beginning
        let oldSidebarList = graph.layersSidebarViewModel.createdOrderedEncodedData()
        let newList = newLayerSidebarDataList + oldSidebarList
        graph.layersSidebarViewModel.update(from: newList)
        
        // Update graph data so that input observers are created
        graph.updateGraphData(document)
        
        // new constants for patches
        for newInputValueSetting in self.patch_data.custom_patch_input_values {
            let inputCoordinate = try NodeIOCoordinate(
                from: newInputValueSetting.patch_input_coordinate,
                idMap: idMap)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      value: newInputValueSetting.value,
                                                      idMap: idMap)
        }
        
        // new constants for layers
        for newInputValueSetting in self.layer_data.custom_layer_input_values {
            let inputCoordinate = try NodeIOCoordinate(
                from: newInputValueSetting.layer_input_coordinate,
                idMap: idMap)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      value: newInputValueSetting.value,
                                                      idMap: idMap)
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
    init(from aiPatchCoordinate: CurrentAIPatchBuilderResponseFormat.NodeIndexedCoordinate,
         idMap: [UUID : UUID]) throws {
        guard let newId = idMap.get(aiPatchCoordinate.node_id.value) else {
            fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have aiPatchCoordinate.node_id \(aiPatchCoordinate.node_id), idMap: \(idMap)")
            throw AIPatchBuilderRequestError.nodeIdNotFound
        }
        
        self.init(portId: aiPatchCoordinate.port_index,
                  nodeId: newId)
    }
    
    init(from aiLayerCoordinate: CurrentAIPatchBuilderResponseFormat.LayerInputCoordinate,
         idMap: [UUID : UUID]) throws {
        guard let newId = idMap.get(aiLayerCoordinate.layer_id.value) else {
            fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have aiLayerCoordinate.layer_id \(aiLayerCoordinate.layer_id), idMap: \(idMap)")
            throw AIPatchBuilderRequestError.nodeIdNotFound
        }
        
        let portType = Step_V0.NodeIOPortType
            .keyPath(.init(layerInput: aiLayerCoordinate.input_port_type.value,
                           portType: .packed))
        
        let migratedPortType = try portType.convert(to: NodeIOPortType.self)
        
        self.init(portType: migratedPortType,
                  nodeId: newId)
    }
}
