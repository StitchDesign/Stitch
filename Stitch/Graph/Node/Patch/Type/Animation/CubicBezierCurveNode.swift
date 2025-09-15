//
//  CubicBezierCurveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/4/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CubicBezierCurvePatchNode: PatchNodeDefinition {
    static let patch = Patch.cubicBezierCurve
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(.zero)],
                    label: "Progress"
                ),
                .init(
                    defaultValues: [.number(0.17)],
                    label: "1st Control Point X"
                ),
                .init(
                    defaultValues: [.number(0.17)],
                    label: "1st Control Point Y"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "2nd Control Point X"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "2nd Control Point Y"
                )
            ],
            outputs: [
                .init(
                    label: "Progress",
                    type: .number
                ),
                .init(
                    label: "2D Progress",
                    type: .position
                )
            ]
        )
    }
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
