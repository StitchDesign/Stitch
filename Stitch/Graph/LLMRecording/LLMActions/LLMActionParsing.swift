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

extension StitchDocumentViewModel {
    @MainActor func openedLLMActionsJSONEntryModal() {
        self.llmRecording.jsonEntryState.showModal = true
        self.graphUI.reduxFocusedField = .llmModal
    }

    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor func closedLLMActionsJSONEntryModal() {
        let jsonEntry = self.llmRecording.jsonEntryState.jsonEntry
        
        self.llmRecording.jsonEntryState.showModal = false
        self.llmRecording.jsonEntryState.jsonEntry = ""
        self.graphUI.reduxFocusedField = nil
        
        guard !jsonEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log("LLMActionsJSONEntryModalClosed: json entry")
            return
        }
        
        do {
            let json = JSON(parseJSON: jsonEntry) // returns null json if parsing fails
            let data = try json.rawData()
            let actions: LLMActions = try JSONDecoder().decode(LLMActions.self,
                                                               from: data)
            actions.forEach { self.handleLLMAction($0) }
            self.llmRecording.jsonEntryState = .init() // reset
            self.graph.encodeProjectInBackground()
        } catch {
            log("LLMActionsJSONEntryModalClosed: Error: \(error)")
            fatalErrorIfDebug("LLMActionsJSONEntryModalClosed: could not retrieve")
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func handleLLMAction(_ action: LLMAction) {
        
        log("handleLLMAction: action: \(action)")
        
        // Make sure we're not "recording", so that functions do
        self.llmRecording.isRecording = false
                
        switch action {
            
        case .addNode(let x):
            // AddNode action has a specific "LLM action node id" i.e. node default title + part of the node id
            // ... suppose we create a node, then move it;
            // the LLM-move-action will expect the specific "LLM action
            
            if let (llmNodeId, nodeKind) = x.node.parseLLMNodeTitle,
               // We created a patch node or layer node; note that patch node is immediately added to the canvas; biut
               let node = self.nodeCreated(choice: nodeKind) {
                self.llmNodeIdMapping.updateValue(node.id,
                                                          forKey: llmNodeId)
            }
            
        // A patch node or layer-input-on-graph was moved
        case .moveNode(let x):
            
            if let canvasItemId = getCanvasIdFromLLMMoveNodeAction(
                llmNode: x.node,
                llmPort: x.port,
                self.llmNodeIdMapping),
               
                // canvas item must exist
               let canvasItem = self.graph.getCanvasItem(canvasItemId) {
                self.graph.updateCanvasItemOnDragged(canvasItem,
                                               translation: x.translation.asCGSize)
            }
               
        case .addEdge(let x):
            
            // Both to node and from node must exist
            guard let (fromNodeId, fromNodeKind) = x.from.node.getNodeIdAndKindFromLLMNode(from: self.llmNodeIdMapping),
                  self.graph.getNode(fromNodeId).isDefined else  {
                log("handleLLMAction: .addEdge: No origin node")
                fatalErrorIfDebug()
                return
            }
            
            guard let (toNodeId, toNodeKind) = x.to.node.getNodeIdAndKindFromLLMNode(from: self.llmNodeIdMapping),
                  self.graph.getNode(toNodeId).isDefined else  {
                log("handleLLMAction: .addEdge: No destination node")
                fatalErrorIfDebug()
                return
            }
            
            guard let fromPort: NodeIOPortType = x.from.port.parseLLMPortAsPortType(fromNodeKind, .output) else {
                log("handleLLMAction: .addEdge: No origin port")
                fatalErrorIfDebug()
                return
            }
            
            guard let toPort: NodeIOPortType = x.to.port.parseLLMPortAsPortType(toNodeKind, .input) else {
                log("handleLLMAction: .addEdge: No destination port")
                fatalErrorIfDebug()
                return
            }
            
            let portEdgeData = PortEdgeData(
                from: .init(portType: fromPort, nodeId: fromNodeId),
                to: .init(portType: toPort, nodeId: toNodeId))
            
            self.graph.edgeAdded(edge: portEdgeData)
            
        case .setInput(let x):
            
            guard let (nodeId, nodeKind) = x.field.node.getNodeIdAndKindFromLLMNode(from: self.llmNodeIdMapping),
                  let node = self.graph.getNode(nodeId) else {
                log("handleLLMAction: .setInput: No node id or node")
                return
            }
            
            guard let portType = x.field.port.parseLLMPortAsPortType(nodeKind, .input) else {
                log("handleLLMAction: .setInput: No port")
                return
            }
            
            let inputCoordinate = InputCoordinate(portType: portType, nodeId: nodeId)
            
            guard let nodeType = x.nodeType.parseLLMNodeType else {
                log("handleLLMAction: .setInput: No node type")
                return
            }
            
            guard let input = self.graph.getInputObserver(coordinate: inputCoordinate) else {
                log("handleLLMAction: .setField: No input")
                return
            }
                        
            // The new value for that entire input, not just for some field
            guard let value: PortValue = x.value.asPortValueForLLMSetField(
                nodeType,
                with: self.llmNodeIdMapping
            ) else {
                log("handleLLMAction: .setField: No port value")
                return
            }
            
            node.removeIncomingEdge(at: inputCoordinate,
                                    activeIndex: self.activeIndex)
            
            input.setValuesInInput([value])
            
            
        case .changeNodeType(let x):
            
            // Node must already exist
            guard let nodeId = x.node.getNodeIdFromLLMNode(from: self.llmNodeIdMapping),
                  self.graph.getNode(nodeId).isDefined else {
                log("handleLLMAction: .changeNodeType: No node id or node")
                return
            }
            
            guard let nodeType = x.nodeType.parseLLMNodeType else {
                log("handleLLMAction: .changeNodeType: No node type")
                return
            }
            
            let _ = self.graph.nodeTypeChanged(nodeId: nodeId, newNodeType: nodeType)

        
        case .addLayerInput(let x):
            self.handleLLMLayerInputOrOutputAdded(llmNode: x.node,
                                                  llmPort: x.port,
                                                  isInput: true)

        case .addLayerOutput(let x):
            self.handleLLMLayerInputOrOutputAdded(llmNode: x.node,
                                                  llmPort: x.port,
                                                  isInput: false)
        }
        
    }
    
    @MainActor
    func handleLLMLayerInputOrOutputAdded(llmNode: String,
                                          llmPort: String,
                                          isInput: Bool) {
        
        // Layer node must already exist
//        guard let nodeId = llmNode.getNodeIdFromLLMNode(from: self.llmNodeIdMapping),
              
        guard let (nodeId, nodeKind) = llmNode.getNodeIdAndKindFromLLMNode(from: self.llmNodeIdMapping),
              let node = self.graph.getNode(nodeId) else {
            log("handleLLMLayerInputOrOutputAdded: No node id or node")
            return
        }
                        
        if isInput {
            
            guard let portType = llmPort.parseLLMPortAsPortType(nodeKind, .input) else {
                log("handleLLMLayerInputOrOutputAdded: No input")
                return
            }
            
            guard let layerInput = portType.keyPath,
                  let layerNode = node.layerNode else {
                log("handleLLMLayerInputOrOutputAdded: No input for \(portType)")
                return
            }
            
            let input = layerNode[keyPath: layerInput.layerNodeKeyPath]
            self.graph.layerInputAddedToGraph(node: node,
                                        input: input,
                                        coordinate: layerInput)
        } else {
            
            guard let portType = llmPort.parseLLMPortAsPortType(nodeKind, .output) else {
                log("handleLLMLayerInputOrOutputAdded: No output")
                return
            }
            
            guard let portId = portType.portId,
                  let layerNode = node.layerNode,
                  let output = layerNode.outputPorts[safe: portId] else {
                log("handleLLMLayerInputOrOutputAdded: No output for \(portType)")
                return
            }
            
            self.graph.layerOutputAddedToGraph(node: node,
                                         output: output,
                                         portId: portId)
        }
    }
}

func getCanvasIdFromLLMMoveNodeAction(llmNode: String,
                                      llmPort: String,
                                      _ mapping: LLMNodeIdMapping) -> CanvasItemId? {
    
    if let (nodeId, nodeKind) = llmNode.getNodeIdAndKindFromLLMNode(from: mapping) {
        
        // Empty `port: String` = we moved a patch or group node
        if llmPort.isEmpty {
            return .node(nodeId)
        }
        
        // Tricky: we know that we have a layer, but don't know whether we moved an input or output
        else if let layerLabel = llmPort.parseLLMPortAsLabelForLayer(nodeKind) {
            switch layerLabel {
            case .keyPath(let x):
                return .layerInput(.init(node: nodeId, keyPath: x))
            case .portIndex(let x):
                return .layerOutput(.init(node: nodeId, portId: x))
            }
        }
    }
    
    return nil
}

extension String {
    
    func parseLLMPortAsLabelForLayer(_ nodeKind: NodeKind) -> NodeIOPortType? {
        
        let llmPort = self
        
        // Prefer to look for layer input first; ASSUMES every layer input has a label
        if let inputLabel = llmPort.parseLLMPortAsLabelForLayerInputType {
            // TODO: support for unpack type in LLM
            return .keyPath(.init(layerInput: inputLabel,
                                  portType: .packed))
        }
        
        // Else, we must have a layer output; note: do layer outputs ALWAYS have labels?
        else if let indexOfOutputLabel = nodeKind.rowDefinitions(for: nil).outputs.firstIndex(where: { $0.label == llmPort }) {
            return .portIndex(indexOfOutputLabel)
        }
        
        return nil
    }
        
    func getNodeIdAndKindFromLLMNode(from mapping: LLMNodeIdMapping) -> (NodeId, NodeKind)? {
        
        if let (llmNodeId, nodeKind) = self.parseLLMNodeTitle,
            let nodeId = mapping.get(llmNodeId) {
            return (nodeId, nodeKind)
        }
        return nil
    }
    
    
    // meant to be called on the .node property of an LLMAction
    func getNodeIdFromLLMNode(from mapping: LLMNodeIdMapping) -> NodeId? {
        if let llmNodeId = self.parseLLMNodeTitleId,
           let nodeId = mapping.get(llmNodeId) {
            return nodeId
        }
        return nil
    }
    
    // Non-empty llmPort is long-form label of the input/output/field;
    // unless there is no label, in which case we use the `portId: Int`.
    
//    func parseLLMPortAsPortType() -> NodeIOPortType? {
//
//    }
    
    func parseLLMPortAsPortType(_ nodeKind: NodeKind,
                                _ nodeIO: NodeIO) -> NodeIOPortType? {
        let llmPort = self
                        
        switch nodeKind {
        case .patch:
            return llmPort.parseLLMPortAsLabelForNonLayer(nodeKind, nodeIO)
        case .layer:
            return llmPort.parseLLMPortAsLabelForLayer(nodeKind)
        case .group:
            fatalErrorIfDebug()
            return nil
        }
        
//        if let portId = Int.init(llmPort) {
//            return .portIndex(portId)
//        } else if let layerInput = llmPort.parseLLMPortAsLabelForLayerInputType {
//            return .keyPath(layerInput)
//        }
//        return nil
    }
    
    // Is this `port: String` for an input/output that has no label?
    var parseLLMPortAsPortId: Int? {
        Int(self)
    }
    
    // Is the `port: String` a label for layer node input?
    var parseLLMPortAsLabelForLayerInputType: LayerInputPort? {
        
        if let layerInput = LayerInputPort.allCases.first(where: {
            $0.label() == self
        }) {
            return layerInput
        }
        return nil
    }
    
    // Is the `port: String` a label for (1) an output or (2) an non-layer-node input?
    // But if you get this back, it could be for an input (non-layer) or an output
    // So what do you return ?
    func parseLLMPortAsLabelForNonLayer(_ nodeKind: NodeKind,
                                        _ nodeIO: NodeIO) -> NodeIOPortType? {
        
//        // Should NOT be used for a label for a layer input
//        guard !self.parseLLMPortAsLabelForLayerInputType.isDefined else {
//            fatalErrorIfDebug()
//            return nil
//        }
        
        let llmPort = self
        
        // if llmPort is an integer-string, then we have an un-labeled input/output on a patch node,
        // and can just return that
        if let portId = llmPort.parseLLMPortAsPortId {
            return .portIndex(portId)
        }

        // Labels do not vary by overall node-type
        let definitions = nodeKind.rowDefinitions(for: nil)
        let indexOfInputLabel = definitions.inputs.firstIndex { $0.label == llmPort }
        let indexOfOutputLabel = definitions.outputs.firstIndex { $0.label == llmPort }
        
        // Assumes that labels on a given patch/layer are unique.
        // Seems a safe/workable assumption for patches and layers; but
        guard let index = indexOfInputLabel ?? indexOfOutputLabel else {
            fatalErrorIfDebug() // We were not able to find
            return nil
        }
        
        return .portIndex(index)
    }
    
    var parseLLMNodeTitleId: String? {
        self.parseLLMNodeTitle?.0
    }
    
    // e.g. for llm node title = "Power (123456)",
    // llm node id is "123456"
    // llm node kind is "Power"
    var parseLLMNodeTitle: (String, NodeKind)? {
        
        var s = self
        
        // Normalize the input by replacing underscores with spaces and capitalizing words
        s = s.replacingOccurrences(of: "_", with: " ").capitalized
        
        // Drop closing parentheses
        s.removeLast()
        
        // Split at and remove opening parentheses
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
            // Normalize the input by removing underscores and lowercasing
            let normalizedInput = self.replacingOccurrences(of: "_", with: "").lowercased()
            
            // Check for special cases
            let specialCases: [String: NodeKind] = [
                "ar anchor": .patch(.arAnchor),
                "ar raycasting": .patch(.arRaycasting),
                "arc tan2": .patch(.arcTan2),
                "qr code detection": .patch(.qrCodeDetection),
                "model 3d import": .patch(.model3DImport),
                "camera feed": .patch(.cameraFeed),
                "square root": .patch(.squareRoot),
                "absolute value": .patch(.absoluteValue),
                "text length": .patch(.textLength),
                "less than": .patch(.lessThan),
                "greater than": .patch(.greaterThan),
                "greater or equal": .patch(.greaterOrEqual),
                "less than or equal": .patch(.lessThanOrEqual),
                "text transform": .patch(.textTransform),
                "text replace": .patch(.textReplace),
                "date and time formatter": .patch(.dateAndTimeFormatter),
                "text starts with": .patch(.textStartsWith),
                "text ends with": .patch(.textEndsWith),
                "video import": .patch(.videoImport),
                "object detection": .patch(.coreMLDetection),
                "image classification": .patch(.coreMLClassify),
                "image import": .patch(.imageImport),
                "when prototype starts": .patch(.whenPrototypeStarts),
            ]
            
            if let specialCase = specialCases[normalizedInput] {
                return specialCase
            }
            
            // If not a special case, proceed with the original logic
            if let layer = Layer.allCases.first(where: { $0.defaultDisplayTitle().lowercased().replacingOccurrences(of: " ", with: "") == normalizedInput }) {
                return .layer(layer)
            } else if let patch = Patch.allCases.first(where: { $0.defaultDisplayTitle().lowercased().replacingOccurrences(of: " ", with: "") == normalizedInput }) {
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
            return x.layerInput.label()
            
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
     
