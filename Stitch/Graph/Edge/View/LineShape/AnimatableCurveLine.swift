//
//  AnimatableCurveLine.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/5/24.
//

import SwiftUI
import StitchSchemaKit

struct AnimatableCurveLine: Shape {

    var from: CGPoint
    var to: CGPoint

    //    let extensionAmount: CGFloat = 36
    //    let extensionAmount: CGFloat = 18
    //    let extensionAmount: CGFloat = 8

    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(to.x, to.y)
        } set(newValue) {
            to.x = newValue.first
            to.y = newValue.second
        }
    }

    var extensionAmount: CGFloat {
        //        min(xGap, 36)
        //        min(xGap, 18)
        //        min(xGap, 8)
        min(xGap, 12)
    }

    var isForwardEdge: Bool {
        to.x > from.x
    }

    var xGap: CGFloat {
        (from.x - to.x).magnitude
    }

    var extendedFrom: CGPoint {
        //        let k = CGPoint(x: from.x + (isForwardEdge ? extensionAmount : -extensionAmount),
        //                        y: from.y)
        let k = CGPoint(x: (from.x + (isForwardEdge ? extensionAmount : -extensionAmount)).rounded(.up),
                        y: from.y.rounded(.up))
        // print("extendedFrom: \(k)")
        return k
    }

    var extendedTo: CGPoint {
        //        let k = CGPoint(x: to.x + (isForwardEdge ? -extensionAmount : extensionAmount),
        //                        y: to.y)
        let k = CGPoint(x: (to.x + (isForwardEdge ? -extensionAmount : extensionAmount)).rounded(.up),
                        y: to.y.rounded(.up))
        // print("extendedTo: \(k)")
        return k
    }

    var control1: CGPoint {
        //        let k = CGPoint(x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2),
        //                        y: extendedFrom.y)
        let k = CGPoint(x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2).rounded(.up),

                        y: extendedFrom.y.rounded(.up))
        // print("control1: \(k)")
        return k
    }

    var control2: CGPoint {
        //        let k = CGPoint(x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2),
        //                        y: extendedTo.y)
        let k = CGPoint(x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2).rounded(.up),
                        y: extendedTo.y.rounded(.up))
        // print("control2: \(k)")
        return k
    }

    func path(in _: CGRect) -> Path {
        Path { p in
            p.move(to: from)
            p.addLine(to: extendedFrom)
            p.addCurve(to: extendedTo,
                       control1: control1,
                       control2: control2)
            p.addLine(to: to)
        }
    }
}
