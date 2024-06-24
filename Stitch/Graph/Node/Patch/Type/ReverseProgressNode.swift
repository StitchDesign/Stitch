//
//  ReversereverseProgressNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit

import SwiftUI

// TODO?: origami's style?
@MainActor
func reverseProgressNode(id: NodeId,
                         n: Double = 50,
                         start: Double = 0,
                         end: Double = 100,
                         position: CGSize = .zero,
                         zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Value", [.number(n)]),
        ("Start", [.number(start)]),
        ("End", [.number(end)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(reverseProgress(n, start: start, end: end))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .reverseProgress,
        inputs: inputs,
        outputs: outputs)
}

func reverseProgressEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    //    log("reverseProgressEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("reverseProgressEval: values: \(values)")
        let n = values[0].getNumber!
        let start = values[1].getNumber!
        let end = values[2].getNumber!

        // ie if n == n2, then just use n
        var reverseProgress: Double = reverseProgress(n, start: start, end: end)

        // TODO: can we find a more principled way of handling this?
        // https://stackoverflow.com/questions/52983262/how-do-i-seperate-negative-zero-from-positive-zero
        // trying to avoid the "-0"
        if reverseProgress == 0 && (reverseProgress.sign == .minus) {
            reverseProgress = 0
        } else if reverseProgress.isNaN {
            reverseProgress = 0
        } else if reverseProgress.isInfinite {
            reverseProgress = 0
        }

        return .number(reverseProgress)
    }

    return resultsMaker(inputs)(op)
}

func reverseProgress(_ n: Double,
                     start: Double = 50,
                     end: Double = 100) -> Double {

    (end - n) / (end - start)
}
