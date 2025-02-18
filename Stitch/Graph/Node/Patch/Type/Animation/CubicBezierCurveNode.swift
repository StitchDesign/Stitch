//
//  CubicBezierCurveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/4/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func cubicBezierCurveNode(id: NodeId,
                          position: CGSize = .zero,
                          zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Progress", [.number(.zero)]), // 0
        // first control point's x
        ("1st Control Point X", [.number(0.17)]), // 1
        // first control point's y
        ("1st Control Point Y", [.number(0.17)]), // 2
        // second control point's x
        ("2nd Control Point X", [.number(0)]), // 3
        // second control point's y
        ("2nd Control Point Y", [.number(1)]) // 4
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Progress", [.number(0)]),
        ("2D Progress", [.position(.zero)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .cubicBezierCurve,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func cubicBezierCurveEval(inputs: PortValuesList,
                          outputs: PortValuesList) -> PortValuesList {

    //    log("cubicBezierCurveEval called")

    let op: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in
        //        log("cubicBezierCurveEval: values: \(values)")
        let progress = values[0].getNumber ?? .zero

        let firstControlPointX = values[1].getNumber ?? .zero
        let firstControlPointY = values[2].getNumber ?? .zero
        let firstControlPoint: CGPoint = .init(x: firstControlPointX,
                                               y: firstControlPointY)

        let secondControlPointX = values[3].getNumber ?? .zero
        let secondControlPointY = values[4].getNumber ?? .zero
        let secondControlPoint: CGPoint = .init(x: secondControlPointX,
                                                y: secondControlPointY)

        // start and end are always 0 and 1
        let p0: CGPoint = .zero // start
        let p3: CGPoint = .init(x: 1, y: 1) // end

        // Control points
        // (Don't need to be between 0 and 1 ?
        let p1: CGPoint = firstControlPoint
        let p2: CGPoint = secondControlPoint

        let xResult = cubicBezierN(t: progress, n0: p0.x, n1: p1.x, n2: p2.x, n3: p3.x)
        let yResult = cubicBezierN(t: progress, n0: p0.y, n1: p1.y, n2: p2.y, n3: p3.y)

        let progressAsPoint = CGPoint.init(x: xResult, y: yResult)

        let progressAsNumber = cubicBezierJS(
            p1x: p1.x,
            p1y: p1.y,
            p2x: p2.x,
            p2y: p2.y,
            x: progress,
            // time in milliseconds
            // curve nodes ALWAYS use 1 second run-time
            duration: 1000)

        return (
            .number(progressAsNumber),
            .position(progressAsPoint)
        )
    }

    return resultsMaker2(inputs)(op)
}
