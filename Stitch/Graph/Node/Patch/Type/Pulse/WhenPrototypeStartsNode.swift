//
//  WhenPrototypeStartsNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/26/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct WhenPrototypeStartsNode: PatchNodeDefinition {
    static let patch: Patch = .whenPrototypeStarts
    
    static func rowDefinitions(for type: StitchSchemaKit.UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .fakeInput
            ],
            outputs: [
                .init(label: "",
                      type: .pulse)
            ]
        )
    }
}

@MainActor
func whenPrototypeStartsEval(node: PatchNode,
                             graphStepState: GraphStepState) -> ImpureEvalResult {

    // Can't use frameCount == 1, since graphTime=0 at that point,
    // and `_shouldPulse` always returns false when graphTime=0
    guard Int(graphStepState.graphFrameCount) == Int(2) else {
        // If we don't have any outputs yet, then this is the first run of the node eval, so provide some default value.
        return .init(outputsValues: [[.pulse(.zero)]])
    }

    // log("whenPrototypeStartsEval: run: \(graphStepState.graphTime)")

    let newOutputValue: PortValues = [.pulse(graphStepState.graphTime)]

    return .init(outputsValues: [newOutputValue])
}
