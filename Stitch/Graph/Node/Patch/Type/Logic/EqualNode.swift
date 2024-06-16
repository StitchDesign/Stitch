//
//  EqualNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// usually pulses are created by timer checks,
// but this one's evaluation creates a pulse, ie a side-effect
@MainActor
func equalsPatchNode(id: NodeId,
                     n1: Double = 0,
                     n2: Double = 0,
                     threshold: Double = 0,
                     position: CGSize = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n1)]),
        (nil, [.number(n2)]),
        ("Threshold", [.number(threshold)])
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
                     patchName: .equals,
                     inputs: inputs,
                     outputs: outputs)
}

func equalsEval(inputs: PortValuesList,
                outputs: PortValuesList) -> PortValuesList {

    resultsMaker(inputs)({ (values: PortValues) -> PortValue in
        if let first = values[0].getNumber,
           let second = values[1].getNumber,
           let threshold = values[2].getNumber {

            return .bool(first.isEqualWithinThreshold(
                            to: second,
                            threshold: threshold))
        }
        log("equalsEval: error")
        return .bool(false)
    })
}

extension Double {
    func isEqualWithinThreshold(to: Double,
                                threshold: Double) -> Bool {

        equalWithinThreshold(n: self,
                             n2: to,
                             threshold: threshold)
    }
}

func equalWithinThreshold(n: Double,
                          n2: Double,
                          threshold: Double = IS_SAME_DIFFERENCE_ALLOWANCE_LEGACY) -> Bool {
    abs(n - n2) <= threshold
}
