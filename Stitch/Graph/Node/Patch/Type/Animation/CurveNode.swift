//
//  CurveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/13/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CurvePatchNode: PatchNodeDefinition {
    static let patch = Patch.curve
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Progress"
                ),
                .init(
                    defaultValues: [.animationCurve(.linear)],
                    label: "Curve"
                )
            ],
            outputs: [
                .init(
                    label: "Progress",
                    type: .number
                )
            ]
        )
    }
}


@MainActor
func curveEval(inputs: PortValuesList,
               outputs: PortValuesList) -> PortValuesList {
    //    log("curveEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("curveEval: values: \(values)")
        let progress = values[0].getNumber ?? .zero
        let curve = values[1].getAnimationCurve ?? .defaultAnimationCurve

        let newProgress = curve.asCurveFormulaProgress(progress)

        return .number(newProgress)
    }

    return resultsMaker(inputs)(op)
}
