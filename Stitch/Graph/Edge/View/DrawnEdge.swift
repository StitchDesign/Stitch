//
//  NewDrawnEdgeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/13/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: `curve` and `line` edges require less information than circuit edges; we could rework some of the edge-related views to not have to do as many calculations
struct DrawnEdge: View {
    static let ANIMATION_DURATION = TimeHelpers.ThreeTenthsOfASecondInSeconds

    @Environment(\.edgeStyle) var edgeStyle

    let from: CGPoint
    let to: CGPoint
    let color: Color
    let isActivelyDragged: Bool

    // the `from` for the edge of the first output on this node
    let firstFrom: CGPoint

    // the `to` for the edge of the first output on this node
    let firstTo: CGPoint

    // the `from` for the edge of the last output on this node
    let lastFrom: CGPoint

    // which output we're on for this node;
    // first output = 1, second = 2, ...
    let fromIndex: Int

    // total number of outputs on this node
    let totalOutputs: Int

    /*
     A given edge set of forward facing edges have a single x distance
     between the outputs and inputs.

     But a given edge set of backward facing edges have multiple y distances between outputs and inputs,
     since the other ports affect the height (y position) of the port.

     So, we use a single y distance, the largest for a given scenario, for a given edge set:
     - destination above: largest from.y vs smallest to.y
     - destination below: smallest from.y vs largest to.y

     */
    let largestYDistance: CGFloat

    let edgeAnimationEnabled: Bool

    var shouldUseBackwardEdge: Bool {
        useBackwardEdge(from: from,
                        to: to,
                        isActivelyDragged: isActivelyDragged)
    }

    // BACKWARD EDGE

    var backwardHalfwayPoint: CGFloat {
        halfYPoint(from,
                   to,
                   fromIndex: fromIndex,
                   firstFrom: firstFrom,
                   firstTo: firstTo,
                   lastFrom: lastFrom,
                   totalOutputs: totalOutputs,
                   useLegacy: useLegacy,
                   largestYDistance: largestYDistance)
    }

    var fromExtends: CGFloat {
        let p = from_extends(from,
                             to,
                             fromIndex: fromIndex,
                             firstFrom: firstFrom,
                             firstTo: firstTo,
                             lastFrom: lastFrom,
                             totalOutputs: totalOutputs,
                             useLegacy: useLegacy,
                             isActivelyDragged: isActivelyDragged)
        //        logInView("_DrawnEdge: fromExtends: \(p)")
        return p
    }

    var fromExtended: CGFloat {
        from.x + fromExtends
    }

    var toExtends: CGFloat {
        let p = to_extends(from,
                           to,
                           fromIndex: fromIndex,
                           firstFrom: firstFrom,
                           firstTo: firstTo,
                           lastFrom: lastFrom,
                           totalOutputs: totalOutputs,
                           useLegacy: useLegacy,
                           isActivelyDragged: isActivelyDragged)
        //        logInView("_DrawnEdge: toExtends: \(p)")
        return p
    }

    var toExtended: CGFloat {
        to.x - toExtends
    }

    // FORWARD EDGE

    var forwardHalfwayPoint: CGFloat {
        Stitch.halfXPoint(from,
                          to,
                          fromIndex: fromIndex,
                          totalOutputs: totalOutputs,
                          useLegacy: useLegacy,
                          isActivelyDragged: isActivelyDragged)
    }

    // varies by backward vs forward
    var halfway: CGFloat {
        shouldUseBackwardEdge ? backwardHalfwayPoint : forwardHalfwayPoint
    }
    
    var animationTime: Double {
        edgeAnimationEnabled ? Self.ANIMATION_DURATION : .zero
    }

    var body: some View {
        // logInView("DrawnEdge: from: \(from)")
        // logInView("DrawnEdge: to: \(to)")
        // logInView("DrawnEdge: fromIndex: \(fromIndex)")
        // logInView("DrawnEdge: totalOutputs: \(totalOutputs)")
        // logInView("DrawnEdge: forwardHalfwayPoint: \(forwardHalfwayPoint)")

        commonLine
            .animation(.linear(duration: animationTime),
                       value: halfway)
            .animation(.linear(duration: animationTime),
                       value: toExtended)
            .animation(.linear(duration: animationTime),
                       value: fromExtended)
    }
    
    var useLegacy: Bool {
        switch edgeStyle {
        case .curve, .line:
            return false
        case .circuit:
            return true
        }
    }

    @ViewBuilder
    var commonLine: some View {
        switch edgeStyle {
        case .curve:
            CurveLine(from: from, to: to)
                .stroke(color,
                        style: StrokeStyle(lineWidth: LINE_EDGE_WIDTH,
                                           lineCap: .round,
                                           lineJoin: .round))

        case .line:
            StraightLine(from: from, to: to)
                .stroke(color,
                        style: StrokeStyle(lineWidth: LINE_EDGE_WIDTH,
                                           lineCap: .round,
                                           lineJoin: .round))

        case .circuit:
            CircuitLine(from: from,
                        fromExtended: fromExtended,
                        midX: forwardHalfwayPoint,
                        midY: backwardHalfwayPoint,
                        to: to,
                        toExtended: toExtended,
                        isBackward: shouldUseBackwardEdge)
                .stroke(color,
                        style: StrokeStyle(lineWidth: LINE_EDGE_WIDTH,
                                           lineCap: .round,
                                           lineJoin: .round))

        }
    }
}
