//
//  ClipNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/20/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func clipNode(id: NodeId,
              n: Double = 0,
              min: Double = -5,
              max: Double = 5,
              position: CGSize = .zero,
              zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Value", [.number(n)]),
        ("Min", [.number(min)]),
        ("Max", [.number(max)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            (nil, [.number(getNumberBetween(value: n, min: min, max: max))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .clip,
        inputs: inputs,
        outputs: outputs)
}

func clipEval(inputs: PortValuesList,
              outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let value = values.first!.getNumber!
        let min = values[1].getNumber!
        let max = values[2].getNumber!
        return .number(getNumberBetween(value: value, min: min, max: max))
    }

    return resultsMaker(inputs)(op)
}

func getNumberBetween(value: Double,
                      min: Double,
                      max: Double) -> Double {
    if value >= max {
        return max
    } else if value <= min {
        return min
    } else {
        return value
    }
}


// i.e. clip
func getNumberBetween(value: Int,
                      min: Int,
                      max: Int) -> Int {
    if value >= max {
        return max
    } else if value <= min {
        return min
    } else {
        return value
    }
}
