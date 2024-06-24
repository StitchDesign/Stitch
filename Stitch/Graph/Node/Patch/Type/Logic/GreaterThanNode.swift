//
//  GreaterThanNode.swift
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
func greaterThanPatchNode(id: NodeId,
                          n: Double = 0,
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
                     patchName: .greaterThan,
                     inputs: inputs,
                     outputs: outputs)
}

func greaterThanEval(values: PortValues) -> PortValues {

    // Return false if comparison fails
    guard let firstValue = values[safe: 0]?.comparableValue,
          let secondValue = values[safe: 1]?.comparableValue else {
        return [.bool(false)]
    }

    return [.bool(firstValue > secondValue)]
}
