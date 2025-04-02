//
//  DevicedeviceTimeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// No node type or user-node types
// No inputs (i.e. inputs are disabled)
@MainActor
func deviceTimeNode(id: NodeId,
                    position: CGPoint = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = fakeInputs(id: id)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Seconds", [numberDefaultFalse]),
        ("Milliseconds", [numberDefaultFalse]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .deviceTime,
        inputs: inputs,
        outputs: outputs)
}

// Doesn't actually need anything
func deviceTimeEval(node: PatchNode) -> EvalResult {

    // All the magic is done by Swift's `Date()` type.
    let currentDeviceTime = Date()
    let seconds = currentDeviceTime.timeIntervalSince1970
    let roundedSeconds = seconds.rounded(.towardZero)
    let milliseconds = seconds - roundedSeconds

    // DeviceTime node has no inputs, and so can never have a loop.
    let newOutputs: PortValuesList = [
        [.number(roundedSeconds)],
        [.number(milliseconds)]
    ]

    return .init(outputsValues: newOutputs)
}
