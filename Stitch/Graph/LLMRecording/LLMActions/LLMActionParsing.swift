//
//  LLMEvents.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftyJSON
import StitchSchemaKit

// MARK: turning a JSON of LLM Actions into state changes in the app

let LLM_OPEN_JSON_ENTRY_MODAL_SF_SYMBOL = "rectangle.and.pencil.and.ellipsis"

struct LLMActionsJSONEntryModalOpened: GraphUIEvent {
    func handle(state: GraphUIState) {
        state.llmRecording.jsonEntryState.showModal = true
        state.reduxFocusedField = .llmModal
    }
}

// When json-entry modal is closed, we turn the JSON of LLMActions into state changes
struct LLMActionsJSONEntryModalClosed: GraphEventWithResponse {
    func handle(state: GraphState) -> GraphResponse {
                
        let jsonEntry = state.graphUI.llmRecording.jsonEntryState.jsonEntry
        
        state.graphUI.llmRecording.jsonEntryState.showModal = false
        state.graphUI.llmRecording.jsonEntryState.jsonEntry = ""
        state.graphUI.reduxFocusedField = nil
        
        guard !jsonEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log("LLMActionsJSONEntryModalClosed: json entry")
            return .noChange
        }
        
        do {
            let json = JSON(parseJSON: jsonEntry) // returns null json if parsing fails
            let data = try json.rawData()
            let actions: LLMActions = try JSONDecoder().decode(LLMActions.self,
                                                               from: data)
            actions.forEach { state.handleLLMAction($0) }
            state.graphUI.llmRecording.jsonEntryState = .init() // reset
            return .shouldPersist
        } catch {
            log("LLMActionsJSONEntryModalClosed: Error: \(error)")
            fatalErrorIfDebug("LLMActionsJSONEntryModalClosed: could not retrieve")
            return .noChange
        }
    }
}

extension GraphState {
    
    @MainActor
    func handleLLMAction(_ action: LLMAction) {
        
        log("handleLLMAction: action: \(action)")
        
        // Make sure we're not "recording", so that functions do
        self.graphUI.llmRecording.isRecording = false
                
        switch action {
            
        case .addNode(let x):
            // AddNode action has a specific "LLM action node id" i.e. node default title + part of the node id
            // ... suppose we create a node, then move it;
            // the LLM-move-action will expect the specific "LLM action
            
            if let (llmNodeId, nodeKind) = x.node.parseLLMNodeTitle,
               // We created a patch node or layer node; note that patch node is immediately added to the canvas; biut
               let nodeId = self.nodeCreated(choice: nodeKind) {
                
                self.graphUI.llmNodeIdMapping.updateValue(nodeId,
                                                                       forKey: llmNodeId)
            }
            
        // A patch node or layer-input-on-graph was moved
        case .moveNode(let x):
            
            if let canvasItemId = getCanvasId(
                llmNode: x.node,
                llmPort: x.port,
                self.graphUI.llmNodeIdMapping),
               
                // canvas item must exist
               let canvasItem = self.getCanvasItem(canvasItemId) {
                self.updateCanvasItemOnDragged(canvasItem,
                                               translation: x.translation.asCGSize)
            }
               
        case .addEdge(let x):
            
            // Both to node and from node must exist
            guard let fromNodeId = x.from.node.getNodeIdFromLLMNode(from: self.graphUI.llmNodeIdMapping),
                  self.getNode(fromNodeId).isDefined else  {
                log("handleLLMAction: .addEdge: No origin node")
                return
            }
            
            guard let toNodeId = x.to.node.getNodeIdFromLLMNode(from: self.graphUI.llmNodeIdMapping),
                  self.getNode(toNodeId).isDefined else  {
                log("handleLLMAction: .addEdge: No destination node")
                return
            }
            
            guard let fromPort: NodeIOPortType = x.from.port.parseLLMPortAsPortType else {
                log("handleLLMAction: .addEdge: No origin port")
                return
            }
            
            guard let toPort: NodeIOPortType = x.to.port.parseLLMPortAsPortType else {
                log("handleLLMAction: .addEdge: No destination port")
                return
            }
            
            let portEdgeData = PortEdgeData(
                from: .init(portType: fromPort, nodeId: fromNodeId),
                to: .init(portType: toPort, nodeId: toNodeId))
            
            self.edgeAdded(edge: portEdgeData)
            
        case .setInput(let x):
            
            guard let nodeId = x.field.node.getNodeIdFromLLMNode(from: self.graphUI.llmNodeIdMapping),
                  let node = self.getNode(nodeId) else {
                log("handleLLMAction: .setField: No node id or node")
                return
            }
            
            guard let portType = x.field.port.parseLLMPortAsPortType else {
                log("handleLLMAction: .setField: No port")
                return
            }
            
            let inputCoordinate = InputCoordinate(portType: portType, nodeId: nodeId)
            
            guard let nodeType = x.nodeType.parseLLMNodeType else {
                log("handleLLMAction: .setField: No node type")
                return
            }
            
            guard let input = self.getInputObserver(coordinate: inputCoordinate) else {
                log("handleLLMAction: .setField: No input")
                return
            }
                        
            // The new value for that entire input, not just for some field
            guard let value: PortValue = x.value.asPortValueForLLMSetField(nodeType) else {
                log("handleLLMAction: .setField: No port value")
                return
            }
            
            node.removeIncomingEdge(at: inputCoordinate,
                                    activeIndex: self.activeIndex)
            
            input.setValuesInInput([value])
            
            
        case .changeNodeType(let x):
            
            // Node must already exist
            guard let nodeId = x.node.getNodeIdFromLLMNode(from: self.graphUI.llmNodeIdMapping),
                  self.getNode(nodeId).isDefined else {
                log("handleLLMAction: .changeNodeType: No node id or node")
                return
            }
            
            guard let nodeType = x.nodeType.parseLLMNodeType else {
                log("handleLLMAction: .changeNodeType: No node type")
                return
            }
            
            let _ = self.nodeTypeChanged(nodeId: nodeId, newNodeType: nodeType)

        
        case .addLayerInput(let x):
            
            // Layer node must already exist
            guard let nodeId = x.node.getNodeIdFromLLMNode(from: self.graphUI.llmNodeIdMapping),
                  let node = self.getNode(nodeId) else {
                log("handleLLMAction: .addLayerInput: No node id or node")
                return
            }
            
            // `.port` should be some known layer input type
            guard let layerInput = x.port.parseLLMPortAsLayerInputType else {
                log("handleLLMAction: .addLayerInput: Unknown port")
                return
            }
            
            guard let input = node.getInputRowObserver(for: .keyPath(layerInput)) else {
                log("handleLLMAction: .addLayerInput: No input for \(layerInput)")
                return
            }
            
            self.layerInputAddedToGraph(node: node,
                                        input: input,
                                        coordinate: layerInput)
            
//
//        case .addLayerOutput(let x):
//            <#code#>
//            
        default:
            fatalError()
        }
        
    }
}

func getCanvasId(llmNode: String,
                 llmPort: String,
                 _ mapping: LLMNodeIdMapping) -> CanvasItemId? {
    
    if let llmNodeId = llmNode.parseLLMNodeTitleId,
       let nodeId = mapping.get(llmNodeId) {
            
        if llmPort.isEmpty {
            return .node(nodeId)
        } else if let portType = llmPort.parseLLMPortAsPortType {
            switch portType {
            case .portIndex(let portId):
                return .layerOutputOnGraph(.init(portId: portId, nodeId: nodeId))
            case .keyPath(let layerInput):
                return .layerInputOnGraph(.init(node: nodeId,
                                                keyPath: layerInput))
            }
        }
    }
    
    return nil
}

extension String {
    
    // meant to be called on the .node property of an LLMAction
    func getNodeIdFromLLMNode(from mapping: LLMNodeIdMapping) -> NodeId? {
        if let llmNodeId = self.parseLLMNodeTitleId,
           let nodeId = mapping.get(llmNodeId) {
            return nodeId
        }
        return nil
    }
    
    var parseLLMPortAsPortType: NodeIOPortType? {
        let llmPort = self
        
        if let portId = Int.init(llmPort) {
            return .portIndex(portId)
        } else if let layerInput = llmPort.parseLLMPortAsLayerInputType {
            return .keyPath(layerInput)
        }
        return nil
    }
    
    var parseLLMPortAsLayerInputType: LayerInputType? {
        
        if let layerInput = LayerInputType.allCases.first(where: {
            $0.label() == self }) {
            return layerInput
        }
        return nil
    }
}
