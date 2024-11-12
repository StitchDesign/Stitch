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
            
            let newCenter = self.newNodeCenterLocation
            
            if let llmNodeId: String = action.nodeId,
               let nodeKind: NodeKind = action.nodeName?.parseLLMStepNodeKind?.asNodeKind,
               let newNode = self.nodeCreated(choice: nodeKind, center: newCenter) {
                
                // TODO: if `action.nodeId` is always a real UUID and is referred to consistently across OpenAI-generated step-actions, then we don't need `llmNodeIdMapping` anymore ?
                self.llmNodeIdMapping.updateValue(newNode.id,
                                                  forKey: llmNodeId)
            } else {
                fatalErrorIfDebug("handleLLMStepAction: could not handle addNode")
            }
                        
        default:
            log("TODO: handle stepType \(stepType)")
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

extension String {
    func toCamelCase() -> String {
        let sentence = self
        let words = sentence.components(separatedBy: " ")
        let camelCaseString = words.enumerated().map { index, word in
            index == 0 ? word.lowercased() : word.capitalized
        }.joined()
        return camelCaseString
    }

    var parseLLMStepNodeKind: PatchOrLayer? {
        
        // E.G. from "squareRoot || Patch", grab just the camelCase "squareRoot"
        if let nodeKindName = self.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) {
            
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
