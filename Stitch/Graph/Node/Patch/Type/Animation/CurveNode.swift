//
//  CurveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/13/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func curveNode(id: NodeId,
               position: CGPoint = .zero,
               zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Progress", [.number(0)]),
        ("Curve", [.animationCurve(.linear)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Progress", [.number(0)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .curve,
        inputs: inputs,
        outputs: outputs)
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
