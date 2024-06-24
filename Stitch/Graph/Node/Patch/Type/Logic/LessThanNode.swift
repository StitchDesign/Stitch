//
//  LessThanNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func lessThanPatchNode(id: NodeId,
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
        values: (nil, [.bool(0 <= n)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .lessThan,
                     inputs: inputs,
                     outputs: outputs)
}

func lessThanEval(values: PortValues) -> PortValues {

    // Return false if comparison fails
    guard let firstValue = values[safe: 0]?.comparableValue,
          let secondValue = values[safe: 1]?.comparableValue else {
        return [.bool(false)]
    }

    return [.bool(firstValue < secondValue)]
}
