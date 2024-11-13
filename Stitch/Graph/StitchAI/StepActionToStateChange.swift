//
//  StepActionToStateChange.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation


// MARK: RECEIVING A LIST OF LLM-STEP-ACTIONS (i.e. `Step`) AND TURNING EACH ACTION INTO A STATE CHANGE

extension StitchDocumentViewModel {
    
    // We've decoded the OpenAI json-response into an array of `LLMStepAction`;
    // Now we turn each `LLMStepAction` into a state-change.
    // TODO: better?: do more decoding logic on the `LLMStepAction`-side; e.g. `LLMStepAction.nodeName` should be type `PatchOrLayer` rather than `String?`
    @MainActor
    func handleLLMStepAction(_ action: LLMStepAction) {
        guard let stepType = StepType(rawValue: action.stepType) else {
            fatalErrorIfDebug("handleLLMStepAction: no step type")
            return
        }
        
        switch stepType {
            
        case .addNode:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeKind: PatchOrLayer = action.parseNodeKind(),
                  let newNode = self.nodeCreated(choice: nodeKind.asNodeKind,
                                              center: self.newNodeCenterLocation) else {
                
                fatalErrorIfDebug("handleLLMStepAction: could not handle addNode")
                return
            }
            
            // TODO: if `action.nodeId` is always a real UUID and is referred to consistently across OpenAI-generated step-actions, then we don't need `llmNodeIdMapping` anymore ?
            self.llmNodeIdMapping.updateValue(newNode.id, forKey: llmNodeId)
                  
            
        case .changeNodeType:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeType: NodeType = action.parseNodeType(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(llmNodeId),
                  let existingNode = self.graph.getNode(nodeId) else {
                
                fatalErrorIfDebug("handleLLMStepAction: could not handle changeNodeType")
                return
            }
            
            let _ = self.graph.nodeTypeChanged(nodeId: existingNode.id,
                                               newNodeType: nodeType)
               
            
        case .setInput:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeType: NodeType = action.parseNodeType(),
                  let value: PortValue = action.parseValue(nodeType),
                  let port: NodeIOPortType = action.parsePort(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(llmNodeId),
                  let existingNode = self.graph.getNode(nodeId) else {
                
                fatalErrorIfDebug("handleLLMStepAction: could not handle setInput")
                return
            }
            
            let inputCoordinate = InputCoordinate(portType: port, nodeId: nodeId)
            
            guard let input = self.graph.getInputObserver(coordinate: inputCoordinate) else {
                log("handleLLMStepAction: .setInput: No input")
                return
            }
            
            existingNode.removeIncomingEdge(at: inputCoordinate,
                                            activeIndex: self.activeIndex)
            
            input.setValuesInInput([value])

            
        case .addLayerInput:
            fatalErrorIfDebug("handleLLMStepAction: need to handle .addLayerInput")
            return

        case .connectNodes:
            
//            LLMStepAction(stepType: StepType.connectNodes.rawValue,
//                          port: .init(value: input.asLLMStepPort()),
//                          fromNodeId: fromNodeId,
//                          toNodeId: toNodeId)
            
            guard let fromNodeId = action.fromNodeId,
                  let toNodeId: String = action.toNodeId,
                  let port: NodeIOPortType = action.parsePort() else {
                return
            }
            
            let fromNodeIdString = NodeEntity.ID(uuidString: fromNodeId)
            let toNodeIdString = NodeEntity.ID(uuidString: toNodeId)

            let fromCoordinate = NodeIOCoordinate(portId: port.id, nodeId: fromNodeIdString!)
            let toCoordinate = NodeIOCoordinate(portId: port.id, nodeId: toNodeIdString!)

            let edge: PortEdgeData = PortEdgeData(from: fromCoordinate, to: toCoordinate)

            let _ = graph.edgeAdded(edge: edge)
            
            
//            if let fromNodeId = step.fromNodeId, let toNodeId = step.toNodeId,
//               let fromNodeInfo = nodeInfoMap[fromNodeId], let toNodeInfo = nodeInfoMap[toNodeId] {
//                let fromNodeTitle = "\(fromNodeInfo.type.capitalized) (\(fromNodeId))"
//                let toNodeTitle = "\(toNodeInfo.type.capitalized) (\(toNodeId))"
//                
//                let portType = step.port?.value ?? toNodeInfo.type.capitalized
//                if !layerInputsAdded.contains("\(toNodeId):\(portType)") {
//                    llmActions.append(LLMActionData(action: ActionType.addLayerInput.rawValue, node: toNodeTitle, nodeType: nil, port: portType.capitalized, from: nil, to: nil, field: nil, value: nil))
//                    layerInputsAdded.insert("\(toNodeId):\(portType)")
//                }
//                
//                let fromEdge = EdgePoint(node: fromNodeTitle, port: "0")
//                let toEdge = EdgePoint(node: toNodeTitle, port: portType.capitalized)
//                llmActions.append(LLMActionData(action: ActionType.addEdge.rawValue, node: nil, nodeType: nil, port: nil, from: fromEdge, to: toEdge, field: nil, value: nil))
//            } else {
//                print("failed to connect nodes")
//            }
//            
            
        }
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

extension LLMStepAction {
    
    func parseValue(_ nodeType: NodeType) -> PortValue? {
        guard let value: StringOrNumber = self.value else {
            log("value was not defined")
            return nil
        }
        
        // TODO: to support a wider range of values, use `JSONFriendlyFormat` instead of `StringOrNumber` and follow older LLMAction-style parsing of LLMSetInput
        if let number = Double(value.value) {
            return .number(number)
        } else {
            return .string(.init(value.value))
        }
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
}

extension String {
    func toCamelCase() -> String {
        let sentence = self
        let words = sentence.components(separatedBy: " ")
        let camelCaseString = words.enumerated().map { index, word in
            index == 0 ? word.lowercased() : word.capitalized
        }.joined()
        return camelCaseString
    }
}
