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
            self.handleLLMLayerInputOrOutputAdded(llmNode: x.node,
                                                  llmPort: x.port,
                                                  isInput: true)

        case .addLayerOutput(let x):
            self.handleLLMLayerInputOrOutputAdded(llmNode: x.node,
                                                  llmPort: x.port,
                                                  isInput: false)
            
        default:
            fatalError()
        }
        
    }
    
    @MainActor
    func handleLLMLayerInputOrOutputAdded(llmNode: String,
                                          llmPort: String,
                                          isInput: Bool) {
        
        // Layer node must already exist
        guard let nodeId = llmNode.getNodeIdFromLLMNode(from: self.graphUI.llmNodeIdMapping),
              let node = self.getNode(nodeId) else {
            log("handleLLMAction: .addLayerPort: No node id or node")
            return
        }
        
        guard let portType = llmPort.parseLLMPortAsPortType else {
            log("handleLLMAction: .addLayerPort: No port")
            return
        }
                
        if isInput {
            guard let layerInput = portType.keyPath,
                  let input = node.getInputRowObserver(for: portType) else {
                log("handleLLMAction: .addLayerPort: No input for \(portType)")
                return
            }
            
            self.layerInputAddedToGraph(node: node,
                                        input: input,
                                        coordinate: layerInput)
        } else {
            guard let portId = portType.portId,
                    let output = node.getOutputRowObserver(for: portType) else {
                log("handleLLMAction: .addLayerPort: No output for \(portType)")
                return
            }
            
            self.layerOutputAddedToGraph(node: node,
                                         output: output,
                                         portId: portId)
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
    
    
    var parseLLMNodeTitleId: String? {
        self.parseLLMNodeTitle?.0
    }
    
    // e.g. for llm node title = "Power (123456)",
    // llm node id is "123456"
    // llm node kind is "Power"
    var parseLLMNodeTitle: (String, NodeKind)? {
        
        var s = self
        
        // drop closing parens
        s.removeLast()
        
        // split at and remove opening parens
        let _s = s.split(separator: "(")
        
        let llmNodeId = (_s.last ?? "").trimmingCharacters(in: .whitespaces)
        let llmNodeKind = (_s.first ?? "").trimmingCharacters(in: .whitespaces).getNodeKind
        
        if let llmNodeKind = llmNodeKind {
            return (llmNodeId, llmNodeKind)
        } else {
            log("parseLLMNodeTitle: unable to parse LLM Node Title")
            return nil
        }
    }
    
    var getNodeKind: NodeKind? {
        // Assumes `self` is already "human-readable" patch/layer name,
        // e.g. "Convert Position" not "convertPosition"
        // TODO: update Patch and Layer enums to use human-readable names for their cases' raw string values; then can just use `Patch(rawValue: self)`
        if let layer = Layer.allCases.first(where: { $0.defaultDisplayTitle() == self }) {
            return .layer(layer)
        } else if let patch = Patch.allCases.first(where: { $0.defaultDisplayTitle() == self }) {
            return .patch(patch)
        }
        
        return nil
    }
}

extension PortValue {
    @MainActor
    var asLLMValue: JSONFriendlyFormat {
                
        switch self {
        // Use shorter ids for assigned-layer nodes
        case .assignedLayer(let x):
            let shorterId = x?.id.debugFriendlyId.description ?? self.display
            return .init(value: .string(.init(shorterId)))
            
        default:
            return .init(value: self)
        }
    }
}

extension NodeIOCoordinate {
    // TODO: use labels if patch node input has that?
    func asLLMPort(nodeKind: NodeKind,
                   nodeIO: NodeIO,
                   nodeType: NodeType?) -> String {
        
        switch self.portType {
        
            // If we have a LayerNode input, use that label
        case .keyPath(let x):
            return x.label()
            
            // If we have a PatchNode input/output, or LayerNode output,
            // try to find the label per node definitions
        case .portIndex(let portId):
            
            let definitions = nodeKind.rowDefinitions(for: nodeType)
            
            switch nodeIO {
            
            case .input:
                let rowLabel = definitions.inputs[safe: portId]?.label ?? ""
                return rowLabel.isEmpty ? portId.description : rowLabel
            
            case .output:
                let rowLabel = definitions.outputs[safe: portId]?.label ?? ""
                return rowLabel.isEmpty ? portId.description : rowLabel
            }
        }
    }
}
     
