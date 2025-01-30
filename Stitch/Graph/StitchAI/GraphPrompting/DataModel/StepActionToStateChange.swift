//
//  StepActionToStateChange.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation


// MARK: RECEIVING A LIST OF LLM-STEP-ACTIONS (i.e. `Step`) AND TURNING EACH ACTION INTO A STATE CHANGE

let CANVAS_ITEM_ADDED_VIA_LLM_STEP_WDITH_STAGGER = 400.0
let CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER = 100.0

extension StitchDocumentViewModel {
    
    // We've decoded the OpenAI json-response into an array of `LLMStepAction`;
    // Now we turn each `LLMStepAction` into a state-change.
    // TODO: better?: do more decoding logic on the `LLMStepAction`-side; e.g. `LLMStepAction.nodeName` should be type `PatchOrLayer` rather than `String?`
    @MainActor
    func handleLLMStepAction(_ action: LLMStepAction,
                             canvasItemsAdded: Int,
                             attempt: Int = 1,
                             maxAttempts: Int = 3) -> Int {
        
        // Check retry attempts
        guard attempt <= maxAttempts else {
            log("❌ All retry attempts exhausted for step action:")
            log("   - Action Type: \(action.stepType)")
            log("   - Node ID: \(action.nodeId ?? "nil")")
            log("   - Node Name: \(action.nodeName ?? "nil")")
            log("   - Port: \(action.port?.value ?? "nil")")
            return canvasItemsAdded
        }
        
        guard let stepType = StepType(rawValue: action.stepType) else {
            log("⚠️ handleLLMStepAction: invalid step type:")
            log("   - Raw Step Type: \(action.stepType)")
            log("   - Attempt: \(attempt) of \(maxAttempts)")
            return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
        }
        
//        let newCenter = CGPoint(
//            x: self.newNodeCenterLocation.x + (CGFloat(canvasItemsAdded) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WDITH_STAGGER),
//            y: self.newNodeCenterLocation.y + (CGFloat(canvasItemsAdded) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER))
        let newCenter = CGPoint(
            x: self.newNodeCenterLocation.x + (CGFloat(canvasItemsAdded) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WDITH_STAGGER),
            y: self.newNodeCenterLocation.y)
        
        switch stepType {
            
        case .addNode:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeId: NodeId = UUID(uuidString: llmNodeId),
                  let nodeKind: PatchOrLayer = action.parseNodeKind(),
                    // Need to explicitly pass in the nodeId from the action
                  let newNode = self.nodeCreated(choice: nodeKind.asNodeKind,
                                                 nodeId: nodeId,
                                                 center: newCenter) else {
                
                log("❌ handleLLMStepAction: addNode failed:")
                log("   - Node ID: \(action.nodeId ?? "nil")")
                log("   - Node Name: \(action.nodeName ?? "nil")")
                log("   - Node Type: \(action.nodeType ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            log("✅ Successfully added node:")
            log("   - Node ID: \(llmNodeId)")
            log("   - Node Kind: \(nodeKind)")
            
            self.llmNodeIdMapping.updateValue(newNode.id, forKey: llmNodeId)
            
            return canvasItemsAdded + 1
                  
        case .changeNodeType:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeType: NodeType = action.parseNodeType(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(llmNodeId),
                  let existingNode = self.graph.getNode(nodeId) else {
                
                log("❌ handleLLMStepAction: changeNodeType failed:")
                log("   - Node ID: \(action.nodeId ?? "nil")")
                log("   - New Type: \(action.nodeType ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
                          
            // ALTERNATIVELY?: Use the patch's default node-type if the LLM gave us an invalid node-type for that patch?
            guard let patch = existingNode.patch,
                  patch.availableNodeTypes.contains(nodeType) else {
                log("❌ handleLLMStepAction: changeNodeType failed because nodeType is not allowed for existing node")
                log("   - Node ID: \(action.nodeId ?? "nil")")
                log("   - Node Patch: \(existingNode.patch.debugDescription ?? "NO PATCH")")
                log("   - New Type: \(action.nodeType ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            let _ = self.graph.nodeTypeChanged(nodeId: existingNode.id,
                                               newNodeType: nodeType)
            
            log("✅ Successfully changed node type:")
            log("   - Node ID: \(llmNodeId)")
            log("   - New Type: \(nodeType)")
            
            return canvasItemsAdded
            
        case .setInput:
            
            guard let port: NodeIOPortType = action.parsePort(),
                  let nodeType: NodeType = action.parseNodeType(),
                  let value: PortValue = action.parseValueForSetInput(
                    nodeType: nodeType,
                    with: self.llmNodeIdMapping),
                  let llmNodeId: String = action.nodeId,
                  let nodeId = self.llmNodeIdMapping.get(llmNodeId),
                  let existingNode = self.graph.getNode(nodeId) else {
                log("❌ handleLLMStepAction: setInput failed - missing required parameters")
                log("   - Port: \(action.port?.value ?? "nil")")
                log("   - Node ID: \(action.nodeId ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            let inputCoordinate = InputCoordinate(portType: port, nodeId: nodeId)
            
            guard let input = self.graph.getInputObserver(coordinate: inputCoordinate) else {
                log("❌ handleLLMStepAction: setInput failed - could not get input observer")
                log("   - Node ID: \(nodeId)")
                log("   - Port: \(port)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            log("handleLLMStepAction: setInput: value: \(value)")
            
            // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
            self.graph.inputEditCommitted(input: input,
                                          nodeId: nodeId,
                                          value: value,
                                          wasDropdown: false)
            
            return canvasItemsAdded
            
        case .addLayerInput:
            
            guard let nodeIdString: String = action.nodeId,
                  let port: NodeIOPortType = action.parsePort(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(nodeIdString) else {
                log("❌ handleLLMStepAction: addLayerInput failed:")
                log("   - Node ID: \(action.nodeId ?? "nil")")
                log("   - Port: \(action.port?.value ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
                        
            guard let node = self.graph.getNode(nodeId) else {
                log("❌ handleLLMStepAction: addLayerInput failed:")
                log("   - Node ID: \(action.nodeId ?? "nil")")
                log("   - Port: \(action.port?.value ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            guard let layerInput = port.keyPath,
                  let layerNode = node.layerNode else {
                log("❌ handleLLMLayerInputOrOutputAdded: No input for \(port)")
                return canvasItemsAdded
            }
            
            let input = layerNode[keyPath: layerInput.layerNodeKeyPath]

            graph.layerInputAddedToGraph(node: node,
                                         input: input,
                                         coordinate: layerInput,
                                         manualLLMStepCenter: newCenter)
            
            return canvasItemsAdded + 1
            
        case .connectNodes:
            
            guard let toPort: NodeIOPortType = action.parsePort(),
                  let fromNodeIdString: String = action.fromNodeId,
                  let toNodeIdString: String = action.toNodeId else {
                log("❌ handleLLMStepAction: connectNodes missing required data:")
                log("   - To Port: \(action.port?.value ?? "nil")")
                log("   - From Node ID: \(action.fromNodeId ?? "nil")")
                log("   - To Node ID: \(action.toNodeId ?? "nil")")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            guard let fromNodeId = self.llmNodeIdMapping.get(fromNodeIdString),
                  let toNodeId = self.llmNodeIdMapping.get(toNodeIdString) else {
                log("❌ handleLLMStepAction: nodes not found for connectNodes:")
                log("   - From Node ID (mapped): \(String(describing: self.llmNodeIdMapping.get(fromNodeIdString)) )")
                log("   - To Node ID (mapped): \(String(describing: self.llmNodeIdMapping.get(toNodeIdString)))")
                log("   - Attempt: \(attempt) of \(maxAttempts)")
                return handleRetry(action: action, canvasItemsAdded: canvasItemsAdded, attempt: attempt, maxAttempts: maxAttempts)
            }
            
            let portValue = action.fromPort?.value ?? "0"
            let fromPortIndex = Int(portValue) ?? 0
            
            let fromCoordinate = OutputCoordinate(portType: .portIndex(fromPortIndex), nodeId: fromNodeId)
            let toCoordinate = InputCoordinate(portType: toPort, nodeId: toNodeId)
            let edge: PortEdgeData = PortEdgeData(from: fromCoordinate, to: toCoordinate)
            let _ = graph.edgeAdded(edge: edge)
            
            log("✅ Successfully connected nodes:")
            log("   - From Node: \(fromNodeIdString) (Port: \(fromPortIndex))")
            log("   - To Node: \(toNodeIdString) (Port: \(toPort))")
            
            return canvasItemsAdded
        }
    }
    
    @MainActor
    private func handleRetry(action: LLMStepAction,
                            canvasItemsAdded: Int,
                            attempt: Int,
                            maxAttempts: Int) -> Int {
        if attempt < maxAttempts {
            log("🔄 Retrying step action:")
            log("   - Action Type: \(action.stepType)")
            log("   - Attempt: \(attempt + 1) of \(maxAttempts)")
            
            // Wait briefly before retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                _ = self.handleLLMStepAction(action,
                                            canvasItemsAdded: canvasItemsAdded,
                                            attempt: attempt + 1,
                                            maxAttempts: maxAttempts)
            }
        } else {
            log("❌ All retries failed, requesting new response from OpenAI")
            // If all retries failed, trigger a new OpenAI request
            retryOpenAIRequest()
        }
        return canvasItemsAdded
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
    
    var parseNodeId: NodeId? {
        self.nodeId?.parseNodeId
    }
        
    @MainActor
    func parseValueForSetInput(nodeType: NodeType,
                               with mapping: LLMNodeIdMapping) -> PortValue? {
        
        guard let value: JSONFriendlyFormat = self.value else {
            log("parseValueForSetInput: value was not defined")
            return nil
        }
        
        return value.asPortValueForLLMSetField(nodeType, with: mapping)
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
enum PatchOrLayer: Equatable, Codable {
    case patch(Patch), layer(Layer)
    
    var asNodeKind: NodeKind {
        switch self {
        case .patch(let patch):
            return .patch(patch)
        case .layer(let layer):
            return .layer(layer)
        }
    }
}
