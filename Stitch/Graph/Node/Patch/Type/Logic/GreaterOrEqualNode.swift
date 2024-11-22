//
//  GreaterOrEqualNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// usually pulses are created by timer checks,
// but this one's evaluation creates a pulse, ie a side-effect
@MainActor
func greaterOrEqualPatchNode(id: NodeId,
                             n: Double = 200,
                             position: CGSize = .zero,
                             zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.comparable(.number(0))]),
        (nil, [.comparable(.number(n))]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.bool(0 >= n)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .greaterOrEqual,
                     inputs: inputs,
                     outputs: outputs)
}

func greaterOrEqualEval(values: PortValues) -> PortValues {

    // Return false if comparison fails
    guard let firstValue = values[safe: 0]?.comparableValue,
          let secondValue = values[safe: 1]?.comparableValue else {
        return [.bool(false)]
    }

    return [.bool(firstValue >= secondValue)]
}
