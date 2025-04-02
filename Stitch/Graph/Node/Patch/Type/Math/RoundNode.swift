//
//  RoundNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/25/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO?: origami's style?
@MainActor
func roundNode(id: NodeId,
               n: Double = 1,
               n2: Double = 0,
               roundUp: Bool = false,
               position: CGPoint = .zero,
               zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n)]),
        ("Places", [.number(n2)]),
        ("Rounded Up", [.bool(roundUp)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(rounded(
                            n,
                            places: Int(n2),
                            roundUp: roundUp))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .round,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func roundEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    //    log("roundEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("roundEval: values: \(values)")
        let n = values[0].getNumber ?? .zero
        let n2 = values[1].getNumber ?? .zero
        let shouldRoundUp = values[2].getBool ?? false

        // ie if n == n2, then just use n
        let round: Double = rounded(n, places: Int(n2), roundUp: shouldRoundUp)

        return .number(round)
    }

    return resultsMaker(inputs)(op)
}

func rounded(_ n: Double,
             places: Int,
             roundUp: Bool) -> Double {

    let r = n.rounded(toPlaces: places)
    if roundUp {
        return r.rounded(.up)
    }
    return r
}
