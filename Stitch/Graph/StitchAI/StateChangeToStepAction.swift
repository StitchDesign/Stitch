//
//  StepTypeActionsFromStateChanges.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/11/24.
//

import Foundation
import SwiftyJSON
import SwiftUI

// MARK: LISTENING TO STATE CHANGES WHIE LLM-RECORDING MODE IS ACTIVE AND TURNING EACH STATE CHANGE INTO AN LLM-STEP-ACTION (i.e. `Step`)

extension StitchDocumentViewModel {
    
    // TODO: see `LLMActionUtil` methods like `maybeCreateLLMMoveNode` etc. for remaining methods that need to be converted from `LLMAction` to `LLMStepAction`
    // fka `maybeCreateLLMAddNode`
    @MainActor
    func maybeCreateStepTypeAddNode(_ newlyCreatedNodeId: NodeId) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           let newlyCreatedNode = self.graph.getNodeViewModel(newlyCreatedNodeId) {
            
            let stepAddNode: LLMStepAction = newlyCreatedNode.createLLMStepAddNode()
            
            log("maybeCreateStepTypeAddNode: stepAddNode: \(stepAddNode)")
            
            // // DEBUG:
            //            let data: Data = try! JSONEncoder().encode(stepAddNode)
            //            let json: JSON = data.toJSON!
            //            // DOES NOT INCLUDE 'NIL' FIELDS
            //            log("maybeCreateStepTypeAddNode: json: \(json)")
            
            self.llmRecording.actions.append(stepAddNode)
        }
    }
    
    @MainActor
    func maybeCreateLLMStepChangeNodeType(node: NodeViewModel,
                                       newNodeType: NodeType) {
        if self.llmRecording.isRecording {
            self.llmRecording.actions.append(node.createLLMStepChangeNodeType(newNodeType))
        }
    }
}

extension NodeViewModel {
    func createLLMStepAddNode() -> LLMStepAction {
        LLMStepAction(stepType: StepType.addNode.rawValue,
                      nodeId: self.id.description, // raw string of UUID
                      nodeName: self.kind.asLLMStepNodeName)
    }
    
    func createLLMStepChangeNodeType(_ newNodeType: NodeType) -> LLMStepAction {
        LLMStepAction(stepType: StepType.changeNodeType.rawValue,
                      nodeId: self.id.description,
                      // Nov 12: Our OpenAI schema currently expects e.g. "text", not "Text"
                      nodeType: newNodeType.asLLMStepNodeType)
    }
}

// `NodeType` is just typealias for `UserVisibleType`, see e.g. `UserVisibleType_V27`
extension NodeType {
    // TODO: our OpenAI schema does not define all possible node-types, and those node types that we do define use camelCase
    // TODO: some node types use human-readable strings ("Sizing Scenario"), not camelCase ("sizingScenario") as their raw value; so can't use `NodeType(rawValue:)` constructor
    var asLLMStepNodeType: String {
        self.display.toCamelCase()
    }
}

extension NodeKind {
    var asLLMStepNodeName: String {
        switch self {
        case .patch(let x):
            // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot || Patch"
            return x.defaultDisplayTitle().toCamelCase() + " || Patch"
        case .layer(let x):
            return x.defaultDisplayTitle().toCamelCase() + " || Layer"
        case .group:
            fatalErrorIfDebug("NodeKind: asLLMStepNodeName: should never create a group node with step actions")
            return ""
        }
    }
}

extension LLMStepActions {
    func asJSON() -> JSON? {
        do {
            let data = try JSONEncoder().encode(self)
            let json = try JSON(data: data)
            log("LLMStepActions: asJSON: encoded json: \(json)")
            return json
        } catch {
            log("LLMStepActions: asJSON: error: \(error)")
            return nil
        }
    }
    
    func asJSONDisplay() -> String {
        self.asJSON()?.description ?? "No LLM-Acceptable Actions Detected"
    }
}
