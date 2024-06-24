//
//  AnimatableForwardCircuitLine.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/5/24.
//

import SwiftUI

struct AnimatableForwardCircuitLine: Shape {

    // All the points except the final destination `to`
    var from: CGPoint
    var midX: CGFloat // forward edges

    // TODO: get rid of midY, which is not needed for animatable forward edges
    var midY: CGFloat // y value; for backward edges
    var to: CGPoint

    // Works well for Forward Above+Below edges
    var animatableData: AP<Double, AP<Double, AP<Double, Double>>> {
        get {
            AP(midX, AP(midY, AP(to.x, to.y)))
        } set(newValue) {
            midX = newValue.first
            midY = newValue.second.first
            to.x = newValue.second.second.first
            to.y = newValue.second.second.second
        }
    }

    func path(in _: CGRect) -> Path {
        Path { p in
            p.move(to: from)
            p.addLine(to: .init(x: midX, y: from.y))
            p.addLine(to: .init(x: midX, y: to.y))
            p.addLine(to: to)
        }
    }
}
