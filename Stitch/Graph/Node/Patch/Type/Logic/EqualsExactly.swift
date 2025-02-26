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
            (nil, [.number(n1)]),
        (nil, [.number(n2)])
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
                     userVisibleType: .number,
                     inputs: inputs,
                     outputs: outputs)
}

@MainActor
func equalsExactlyEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {
    
    let op: Operation = { (values: PortValues) -> PortValue in
        guard let firstValue = values.first else {
            return .bool(false)
        }
        
        // All values must be exactly the same as each other (fine to check against first value),
        // otherwise we return false.
        return .bool(values.allSatisfy({ $0 == firstValue }))
    }
    
    return resultsMaker(inputs)(op)
}
