//
//  Shapes.swift
//  prototype
//
//  Created by cjc on 11/8/20.
//

import Combine
import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 -- MARK: UI ELEMENTS: drawn edges etc.
 ---------------------------------------------------------------- */

let LINE_EDGE_WIDTH = NODE_ROW_HEIGHT

struct Line: Shape {
    let from, to: CGPoint

    func path(in _: CGRect) -> Path {
        Path { p in
            p.move(to: self.from)
            p.addLine(to: self.to)
        }
    }
}

struct CircuitLine: Shape {

    // All the points except the final destination `to`
    var from: CGPoint
    var fromExtended: CGFloat

    var midX: CGFloat // forward edges

    var midY: CGFloat // y value; for backward edges

    var to: CGPoint
    var toExtended: CGFloat

    var isBackward: Bool

    // Don't animate `to`
    //    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
    var animatableData: AnimatablePair<Double,
                                       AnimatablePair<Double,
                                                      AnimatablePair<Double, Double>>> {
        get {
            AnimatablePair(midX,
                           AnimatablePair(midY,
                                          AnimatablePair(fromExtended,
                                                         toExtended)))

        } set(newValue) {
            midX = newValue.first
            midY = newValue.second.first
            fromExtended = newValue.second.second.first
            toExtended = newValue.second.second.second
        }
    }

    func path(in _: CGRect) -> Path {
        Path { p in

            if isBackward {
                p.move(to: from)
                p.addLine(to: .init(x: fromExtended, y: from.y))
                p.addLine(to: .init(x: fromExtended, y: midY))
                p.addLine(to: .init(x: toExtended, y: midY))
                p.addLine(to: .init(x: toExtended, y: to.y))
                p.addLine(to: to)
            } else {
                p.move(to: from)
                p.addLine(to: .init(x: midX, y: from.y))
                p.addLine(to: .init(x: midX, y: to.y))
                p.addLine(to: to)
            }
        }
    }
}
