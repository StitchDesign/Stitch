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
                          
        case .addLayerInput:
            fatalErrorIfDebug("handleLLMStepAction: need to handle .addLayerInput")
            return

        case .connectNodes:
            fatalErrorIfDebug("handleLLMStepAction: need to handle .connectNodes")
            return

        case .setInput:
            fatalErrorIfDebug("handleLLMStepAction: need to handle .setInput")
            return
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
