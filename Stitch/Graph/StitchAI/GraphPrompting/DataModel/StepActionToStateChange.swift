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
    func applyAction(_ action: StepTypeAction) -> LLMActionsInvalidMessage? {
        
        // Set true whenever we are
        self.llmRecording.isApplyingActions = true
                        
        switch action {
        case .addNode(let x):
            guard let _ = self.nodeCreated(choice: x.nodeName.asNodeKind,
                                           nodeId: x.nodeId) else {
                log("applyAction: could not apply addNode")
                self.llmRecording.isApplyingActions = false
                return .init("Applying Action: could not create node \(x.nodeId.debugFriendlyId) \(x.nodeName)")
            }
            self.llmRecording.isApplyingActions = false
            
        case .addLayerInput(let x):
            guard let node = self.graph.getNode(x.nodeId),
                  let layerNode = node.layerNode else {
                log("applyAction: could not apply addLayerInput")
                self.llmRecording.isApplyingActions = false
                return .init("Applying Action: node \(x.nodeId.debugFriendlyId) did not exist in state or was not a layer")
            }
            
            let layerInputType = x.port.asFullInput
            let input = layerNode[keyPath: layerInputType.layerNodeKeyPath]

            self.graph.layerInputAddedToGraph(node: node,
                                              input: input,
                                              coordinate: layerInputType)
            self.llmRecording.isApplyingActions = false
        
        case .connectNodes(let x):
            let edge: PortEdgeData = PortEdgeData(
                from: .init(portType: .portIndex(x.fromPort), nodeId: x.fromNodeId),
                to: .init(portType: x.port, nodeId: x.toNodeId))
            
            let _ = graph.edgeAdded(edge: edge)
            self.llmRecording.isApplyingActions = false
        
        case .changeNodeType(let x):
            // NodeType etc. for this patch was already validated in `[StepTypeAction].areValidLLMSteps`
            let _ = self.graph.nodeTypeChanged(nodeId: x.nodeId,
                                               newNodeType: x.nodeType)
            self.llmRecording.isApplyingActions = false
        
        case .setInput(let x):
            let inputCoordinate = InputCoordinate(portType: x.port,
                                                  nodeId: x.nodeId)
            guard let input = self.graph.getInputObserver(coordinate: inputCoordinate) else {
                log("applyAction: could not apply setInput")
                self.llmRecording.isApplyingActions = false
                return .init("Applying Action: could not retrieve input \(inputCoordinate)")
            }
            
            // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
            self.graph.inputEditCommitted(input: input,
                                          nodeId: x.nodeId,
                                          value: x.value,
                                          wasDropdown: false)
            
            self.llmRecording.isApplyingActions = false
        }

        return nil // nil = no errors or invalidations
    }
}

extension NodeIOPortType {
    // TODO: `LLMStepAction`'s `port` parameter does not yet properly distinguish between input vs output?
    // Note: the older LLMAction port-string-parsing logic was more complicated?
    init?(stringValue: String?) {
        guard let port = stringValue else { return nil }
  
        if let portId = Int(port) {
            // could be patch input/output OR layer output
            self = .portIndex(portId)
        } else if let portId = Double(port) {
            // could be patch input/output OR layer output
            self = .portIndex(Int(portId))
        } else if let layerInputPort: LayerInputPort = LayerInputPort.allCases.first(where: { $0.asLLMStepPort == port }) {
            let layerInputType = LayerInputType(layerInput: layerInputPort,
                                                // TODO: support unpacked with StitchAI
                                                portType: .packed)
            self = .keyPath(layerInputType)
        } else {
            log("could not parse LLMStepAction's port: \(port)")
            fatalErrorIfDebug()
            return nil
        }
    }
}

extension NodeType {
    init(llmString: String) throws {
        guard let match = NodeType.allCases.first(where: {
            $0.asLLMStepNodeType == llmString
        }) else {
            throw StitchAIManagerError.nodeTypeParsing(llmString)
        }
        
        self = match
    }
}

extension PatchOrLayer {
    // Note: Swift `init?` is tricky for returning nil vs initializing self; we have to both initialize self *and* return, else we continue past if/else branches etc.;
    // let's prefer functions with clearer return values
    static func fromLLMNodeName(_ nodeName: String) throws -> Self {
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
        
        throw StitchAIManagerError.nodeNameParsing(nodeName)
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
