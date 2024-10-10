//
//  ProgressNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/25/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func progressNode(id: NodeId,
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
            (nil, [.number(progress(n, start: start, end: end))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .progress,
        inputs: inputs,
        outputs: outputs)
}

func progressEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    //    log("progressEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("progressEval: values: \(values)")
        let n = values[0].getNumber ?? .zero
        let start = values[1].getNumber ?? .zero
        let end = values[2].getNumber ?? .zero

        // ie if n == n2, then just use n
        var progress: Double = progress(n, start: start, end: end)

        // TODO: can we find a more principled way of handling this?
        // https://stackoverflow.com/questions/52983262/how-do-i-seperate-negative-zero-from-positive-zero
        // trying to avoid the "-0"
        if progress == 0 && (progress.sign == .minus) {
            progress = 0
        } else if progress.isNaN {
            progress = 0
        } else if progress.isInfinite {
            progress = 0
        }

        return .number(progress)
    }

    return resultsMaker(inputs)(op)
}

func progress(_ n: Double,
              start: Double = 50,
              end: Double = 100) -> Double {

    (start - n) / ( start - end)
}
