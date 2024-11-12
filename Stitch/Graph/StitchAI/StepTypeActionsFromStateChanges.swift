//
//  StepTypeActionsFromStateChanges.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/11/24.
//

import Foundation


extension NodeViewModel {
    func createLLMStepAddNode() -> LLMStepAction {
        LLMStepAction(stepType: StepType.addNode.rawValue,
                      nodeId: self.id.description, // raw string of UUID
                      nodeName: self.kind.asLLMStepNodeName)
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
