//
//  PossibleEdgesView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/24.
//

import SwiftUI

extension Double {
    //    static let POSSIBLE_EDGE_ANIMATION_DURATION: Double = 0.6 // debug
    static let POSSIBLE_EDGE_ANIMATION_DURATION: Double = 0.15 // best?
}

struct PossibleEdgeView: View {

    let edgeStyle: EdgeStyle
    let possibleEdge: PossibleEdge
    let shownPossibleEdgeIds: Set<PossibleEdgeId>
    let from: CGPoint
    let to: CGPoint
    let totalOutputs: Int
    let color: Color

    var body: some View {

        switch edgeStyle {

        case .circuit:
            PossibleEdgeCircuitView(
                possibleEdge: possibleEdge,
                shownPossibleEdgeIds: shownPossibleEdgeIds,
                from: from,
                to: to,
                totalOutputs: totalOutputs,
                color: color)

        case .curve, .line:
            PossibleEdgeSimpleView(
                possibleEdge: possibleEdge,
                shownPossibleEdgeIds: shownPossibleEdgeIds,
                from: from,
                to: to,
                color: color,
                isCurve: edgeStyle == .curve)
        }
    }
}

struct PossibleEdgeCircuitView: View {
    let possibleEdge: PossibleEdge
    let shownPossibleEdgeIds: Set<PossibleEdgeId>
    let from: CGPoint
    let to: CGPoint
    let totalOutputs: Int
    let color: Color

    var body: some View {
        let isShown = shownPossibleEdgeIds.contains(possibleEdge.edge.to)
        
        let forwardHalfwayPoint = halfXPoint(
            from,
            to,
            fromIndex: possibleEdge.edge.fromIndex,
            totalOutputs: totalOutputs,
            useLegacy: false,
            isActivelyDragged: false)
        
        AnimatableForwardCircuitLine(
            from: from,
            midX: possibleEdge.isCommitted ? forwardHalfwayPoint : from.x,
            midY: .zero, // ignored by Forward Circuit edges
            to: possibleEdge.isCommitted ? to : from)
        .possibleEdgeModifier(
            color: color,
            isCommitted: possibleEdge.isCommitted,
            isShown: isShown)
    }
}

extension Shape {
    func possibleEdgeModifier(color: Color,
                              isCommitted: Bool,
                              isShown: Bool) -> some View {
        self
            .stroke(color,
                    style: StrokeStyle(lineWidth: LINE_EDGE_WIDTH,
                                       lineCap: .round,
                                       lineJoin: .round))
            .animation(.linear(duration: .POSSIBLE_EDGE_ANIMATION_DURATION),
                       value: isCommitted)
            .opacity(isShown ? 1 : 0)
            .allowsHitTesting(false)
    }
}

// `Curve` and `Straight` edge styles are simpler than `Circuit`
struct PossibleEdgeSimpleView: View {
    let possibleEdge: PossibleEdge
    let shownPossibleEdgeIds: Set<InputPortIdAddress>
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let isCurve: Bool
    
    var body: some View {
        let isShown = shownPossibleEdgeIds.contains(possibleEdge.id)
        
        if isCurve {
            AnimatableCurveLine(from: from,
                                to: possibleEdge.isCommitted ? to : from)
            .possibleEdgeModifier(
                color: color,
                isCommitted: possibleEdge.isCommitted,
                isShown: isShown)
        } else {
            AnimatableStraightLine(from: from,
                                   to: possibleEdge.isCommitted ? to : from)
            .possibleEdgeModifier(
                color: color,
                isCommitted: possibleEdge.isCommitted,
                isShown: isShown)
        }
    }
}
