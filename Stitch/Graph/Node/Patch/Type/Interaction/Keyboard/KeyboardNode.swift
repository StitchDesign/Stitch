//
//  KeyboardNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/15/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct KeyboardNode: PatchNodeDefinition {
    static let patch: Patch = .keyboard

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(defaultValues: [.string(.init("a"))], label: "Key")
            ],
            outputs: [
                .init(label: "Down",
                      type: .bool)
            ]
        )
    }
}

// returns (new outputs, updated key-press-state)
@MainActor
func keyboardEval(node: PatchNode,
                  graph: GraphState) -> EvalResult {

    // We should always have a document delegate
    assertInDebug(graph.documentDelegate.isDefined)
    
    let graphTime = graph.graphStepState.graphTime
    let keypressState = graph.documentDelegate?.keypressState ?? .init()

    return node.loopedEval { values, _ in
        let character = values.first?.getString?.string ?? ""
        // log("keyboardEval: op: character: \(character)")
        // log("keyboardEval: op: keypressState.characters: \(keypressState.characters)")
        return [.bool(keypressState.characters.contains(character))]
    }
    .createPureEvalResult()
}
