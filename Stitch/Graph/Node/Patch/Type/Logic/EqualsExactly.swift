//
//  EqualsExactlyExactly.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// usually pulses are created by timer checks,
// but this one's evaluation creates a pulse, ie a side-effect
@MainActor
func equalsExactlyPatchNode(id: NodeId,
                            n1: Double = 0,
                            n2: Double = 0,
                            threshold: Double = 0,
                            position: CGSize = .zero,
                            zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.comparable(.number(n1))]),
        (nil, [.comparable(.number(n2))])
    )

    let outputValue = n1.isEqualWithinThreshold(
        to: n2,
        threshold: threshold)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.bool(outputValue)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .equalsExactly,
                     inputs: inputs,
                     outputs: outputs)
}

func equalsExactlyEval(inputValues: PortValues) -> PortValues {

    // Return false if failure case
    guard let firstValue = inputValues[safe: 0]?.comparableValue,
          let secondValue = inputValues[safe: 1]?.comparableValue else {
        return [.bool(false)]
    }

    return [.bool(firstValue.number == secondValue.number)]
}
