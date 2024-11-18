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
                             canvasItemsAdded: Int) -> Int {
        
        guard let stepType = StepType(rawValue: action.stepType) else {
            fatalErrorIfDebug("handleLLMStepAction: no step type")
            return canvasItemsAdded
        }
        
        let newCenter = CGPoint(
            x: self.newNodeCenterLocation.x + (CGFloat(canvasItemsAdded) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WDITH_STAGGER),
            y: self.newNodeCenterLocation.y + (CGFloat(canvasItemsAdded) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER))
        
        switch stepType {
            
        case .addNode:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeKind: PatchOrLayer = action.parseNodeKind(),
                  let newNode = self.nodeCreated(choice: nodeKind.asNodeKind,
                                                 center: newCenter) else {
                
                fatalErrorIfDebug("handleLLMStepAction: could not handle addNode")
                return canvasItemsAdded
            }
            
            // TODO: if `action.nodeId` is always a real UUID and is referred to consistently across OpenAI-generated step-actions, then we don't need `llmNodeIdMapping` anymore ?
            self.llmNodeIdMapping.updateValue(newNode.id, forKey: llmNodeId)
            
            return canvasItemsAdded + 1
                  
        case .changeNodeType:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeType: NodeType = action.parseNodeType(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(llmNodeId),
                  let existingNode = self.graph.getNode(nodeId) else {
                
                fatalErrorIfDebug("handleLLMStepAction: could not handle changeNodeType")
                return canvasItemsAdded
            }
            
            let _ = self.graph.nodeTypeChanged(nodeId: existingNode.id,
                                               newNodeType: nodeType)
            
            return canvasItemsAdded
               
        case .setInput:
            
            guard let llmNodeId: String = action.nodeId,
                  let nodeType: NodeType = action.parseNodeType(),
                  let value: PortValue = action.parseValue(nodeType),
                  let port: NodeIOPortType = action.parsePort(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(llmNodeId),
                  let existingNode = self.graph.getNode(nodeId) else {
                
                fatalErrorIfDebug("handleLLMStepAction: could not handle setInput")
                return canvasItemsAdded
            }
            
            let inputCoordinate = InputCoordinate(portType: port, nodeId: nodeId)
            
            guard let input = self.graph.getInputObserver(coordinate: inputCoordinate) else {
                log("handleLLMStepAction: .setInput: No input")
                return canvasItemsAdded
            }
            
            existingNode.removeIncomingEdge(at: inputCoordinate,
                                            activeIndex: self.activeIndex)
            
            input.setValuesInInput([value])
            
            return canvasItemsAdded
            
        case .addLayerInput:
            
            guard let nodeIdString: String = action.nodeId,
                  let port: NodeIOPortType = action.parsePort(),
                  // Node must already exist
                  let nodeId = self.llmNodeIdMapping.get(nodeIdString) else {
                fatalErrorIfDebug("handleLLMStepAction: could not handle addLayerInput")
                return canvasItemsAdded
            }
                        
            guard let node = self.graph.getNode(nodeId) else {
                fatalErrorIfDebug("handleLLMStepAction: could not handle addLayerInput")
                return canvasItemsAdded
            }
            
            guard let layerInput = port.keyPath,
                  let layerNode = node.layerNode else {
                log("handleLLMLayerInputOrOutputAdded: No input for \(port)")
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
                  let fromPort: Int = action.parseFromPort() else {
                fatalErrorIfDebug("handleLLMStepAction: could not handle connectNodes: could not parse to-port and from-port")
                return canvasItemsAdded
            }
            
            guard let fromNodeIdString: String = action.fromNodeId,
                  let toNodeIdString: String = action.toNodeId else {
                fatalErrorIfDebug("handleLLMStepAction: could not handle connectNodes: could not parse from- and to-nodeIds")
                return canvasItemsAdded
            }
            
            // Node must already exist
            guard let fromNodeId = self.llmNodeIdMapping.get(fromNodeIdString),
                  let toNodeId = self.llmNodeIdMapping.get(toNodeIdString) else {
                fatalErrorIfDebug("handleLLMStepAction: could not handle connectNodes: nodes did not already exist")
                return canvasItemsAdded
            }
            
            // Currently all edges are assumed to be extending from the first output of a patch node
            let fromCoordinate = InputCoordinate(portType: .portIndex(fromPort), nodeId: fromNodeId)
            
            // ... But an edge could be coming into a
            let toCoordinate = InputCoordinate(portType: toPort, nodeId: toNodeId)

            let edge: PortEdgeData = PortEdgeData(from: fromCoordinate, to: toCoordinate)
            let _ = graph.edgeAdded(edge: edge)
            
            return canvasItemsAdded
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
    
    func parseFromPort() -> Int? {
        guard let fromPort: String = self.fromPort else {
            log("fromPort was not defined")
            // For legacy reasons, assume 0
//            return nil
            return 0
        }
          
        if let portId = Int(fromPort) {
            return portId
        } else if let portId = Double(fromPort) {
            return Int(portId)
        } else {
            log("could not parse LLMStepAction's fromPort: \(fromPort)")
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
