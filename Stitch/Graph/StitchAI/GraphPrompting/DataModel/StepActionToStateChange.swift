//
//  StepActionToStateChange.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation


// MARK: RECEIVING A LIST OF LLM-STEP-ACTIONS (i.e. `Step`) AND TURNING EACH ACTION INTO A STATE CHANGE

//let CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER = 400.0
let CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER = 600.0 // needed for especially wide nodes

//let CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER = 100.0
let CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER = 300.0 // needed for when nodes are at same topo depth level


extension StitchDocumentViewModel {
    
    // We've decoded the OpenAI json-response into an array of `LLMStepAction`;
    // Now we turn each `LLMStepAction` into a state-change.
    // TODO: better?: do more decoding logic on the `LLMStepAction`-side; e.g. `LLMStepAction.nodeName` should be type `PatchOrLayer` rather than `String?`
    
        
    // fka `handleLLMStepAction`
    // returns nil = failed, and should retry
    @MainActor
    func applyAction(_ action: StepTypeAction,
                     canvasItemsAdded: Int) -> Int? {
        
        // Set true whenever we are
        self.llmRecording.isApplyingActions = true
        
        let newCenter = CGPoint(
            x: self.newNodeCenterLocation.x + (CGFloat(canvasItemsAdded) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER),
            y: self.newNodeCenterLocation.y)
                
        switch action {
        case .addNode(let x):
            guard let _ = self.nodeCreated(choice: x.nodeName.asNodeKind,
                                           nodeId: x.nodeId,
                                           center: newCenter) else {
                self.llmRecording.isApplyingActions = false
                return nil
            }
            self.llmRecording.isApplyingActions = false
            return canvasItemsAdded + 1
            
        case .addLayerInput(let x):
            guard let node = self.graph.getNode(x.nodeId),
                  let layerNode = node.layerNode else {
                self.llmRecording.isApplyingActions = false
                return nil
            }
            
            let layerInputType = x.port.asFullInput
            let input = layerNode[keyPath: layerInputType.layerNodeKeyPath]

            self.graph.layerInputAddedToGraph(node: node,
                                              input: input,
                                              coordinate: layerInputType,
                                              manualLLMStepCenter: newCenter)
            self.llmRecording.isApplyingActions = false
            return canvasItemsAdded + 1
        
        case .connectNodes(let x):
            let edge: PortEdgeData = PortEdgeData(
                from: .init(portType: x.fromPort, nodeId: x.fromNodeId),
                to: .init(portType: x.port, nodeId: x.toNodeId))
            
            let _ = graph.edgeAdded(edge: edge)
            self.llmRecording.isApplyingActions = false
            return canvasItemsAdded
        
        case .changeNodeType(let x):
            // NodeType etc. for this patch was already validated in `[StepTypeAction].areValidLLMSteps`
            let _ = self.graph.nodeTypeChanged(nodeId: x.nodeId,
                                               newNodeType: x.nodeType)
            self.llmRecording.isApplyingActions = false
            return canvasItemsAdded
        
        case .setInput(let x):
            let inputCoordinate = InputCoordinate(portType: x.port,
                                                  nodeId: x.nodeId)
            guard let input = self.graph.getInputObserver(coordinate: inputCoordinate) else {
                self.llmRecording.isApplyingActions = false
                return nil
            }
            
            // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
            self.graph.inputEditCommitted(input: input,
                                          nodeId: x.nodeId,
                                          value: x.value,
                                          wasDropdown: false)
            
            self.llmRecording.isApplyingActions = false
            return canvasItemsAdded
        }
        
    }
    
    @MainActor
    func handleRetry() {
        if self.llmRecording.attempts < LLMRecordingState.maxAttempts {
            self.llmRecording.attempts += 1
            retryOpenAIRequest()
        } else {
            fatalErrorIfDebug("Ran out of retry attempts")
            return
        }
    }
    
    @MainActor
    private func retryOpenAIRequest() {
        // Re-trigger the OpenAI request with the original prompt
        if let lastPrompt = stitchAI.lastPrompt,
           !lastPrompt.isEmpty {
            log("🔄 Retrying OpenAI request with last prompt")
            dispatch(MakeOpenAIRequest(prompt: lastPrompt))
        } else {
            log("❌ Cannot retry OpenAI request: No last prompt available")
        }
    }
}

extension String {
    var parseNodeId: NodeId? {
        UUID(uuidString: self)
    }
}

extension LLMStepAction {
    
    var parseStepType: StepType? {
        StepType(rawValue: self.stepType)
    }
    
    var parseNodeId: NodeId? {
        self.nodeId?.parseNodeId
    }
        
    func parseValueForSetInput(nodeType: NodeType) -> PortValue? {
        
        guard let value: JSONFriendlyFormat = self.value else {
            log("parseValueForSetInput: value was not defined")
            return nil
        }
        
        return value.asPortValueForLLMSetField(nodeType)
    }
    
    // TODO: `LLMStepAction`'s `port` parameter does not yet properly distinguish between input vs output?
    // Note: the older LLMAction port-string-parsing logic was more complicated?
    func parsePort() -> NodeIOPortType? {
        guard let port: StringOrNumber = self.port else {
            log("port was not defined")
            return nil
        }
  
        if let portId = Int(port.value) {
            // could be patch input/output OR layer output
            return .portIndex(portId)
        } else if let portId = Double(port.value) {
            // could be patch input/output OR layer output
            return .portIndex(Int(portId))
        } else if let layerInputPort: LayerInputPort = LayerInputPort.allCases.first(where: {$0.asLLMStepPort == port.value }) {
            let layerInputType = LayerInputType(layerInput: layerInputPort,
                                                // TODO: support unpacked with StitchAI
                                                portType: .packed)
            return .keyPath(layerInputType)
        } else {
            log("could not parse LLMStepAction's port: \(port)")
            return nil
        }
    }
    
    func parseFromPort() -> Int? {
        guard let fromPort: StringOrNumber = self.fromPort else {
            log("fromPort was not defined")
            // For legacy reasons, assume 0
//            return 0
            
            // Do not assume 0; all our data should be updated and accurate now
            return nil
        }
        
        // Try to convert the string value to Int
        return Int(fromPort.value) ?? 0
    }
    
    // See note in `NodeType.asLLMStepNodeType`
    func parseNodeType() -> NodeType? {
        guard let nodeType = self.nodeType else {
            log("nodeType was not defined")
            return nil
        }
        
        return NodeType.allCases.first {
            $0.asLLMStepNodeType == nodeType
        }
    }
    
    
    func parseNodeKind() -> PatchOrLayer? {
        
        guard let nodeName = self.nodeName else {
            log("nodeName was not defined")
            return nil
        }
        
        return nodeName.parseNodeKind()
    }
}

extension String {
    
    func parseNodeKind() -> PatchOrLayer? {
        let nodeName = self
        
        // E.G. from "squareRoot || Patch", grab just the camelCase "squareRoot"
        if let nodeKindName = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) {
            
            // Tricky: can't use `Patch(rawValue:)` constructor since newer patches use a non-camelCase rawValue
            if let patch = Patch.allCases.first(where: {
                // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot"
                let patchDisplay = $0.defaultDisplayTitle().toCamelCase()
                return patchDisplay == nodeKindName
            }) {
                return .patch(patch)
            }
            
            else if let layer = Layer.allCases.first(where: {
                $0.defaultDisplayTitle().toCamelCase() == nodeKindName
            }) {
                return .layer(layer)
            }
        }
        
        log("parseLLMStepNodeKind: could not parse \(self) as PatchOrLayer")
        return nil
    }
    
    func toCamelCase() -> String {
        let sentence = self
        let words = sentence.components(separatedBy: " ")
        let camelCaseString = words.enumerated().map { index, word in
            index == 0 ? word.lowercased() : word.capitalized
        }.joined()
        return camelCaseString
    }
}

// i.e. NodeKind, excluding Group Nodes
enum PatchOrLayer: Equatable, Codable, Hashable {
    case patch(Patch), layer(Layer)
    
    var asNodeKind: NodeKind {
        switch self {
        case .patch(let patch):
            return .patch(patch)
        case .layer(let layer):
            return .layer(layer)
        }
    }
    
    static func from(nodeKind: NodeKind) -> Self? {
        switch nodeKind {
        case .patch(let x):
            return .patch(x)
        case .layer(let x):
            return .layer(x)
        case .group:
            fatalErrorIfDebug()
            return nil
        }
    }
}
