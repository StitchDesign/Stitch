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

struct RoundPatchNode: PatchNodeDefinition {
    static let patch = Patch.round

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Places"
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Rounded Up",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }
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
