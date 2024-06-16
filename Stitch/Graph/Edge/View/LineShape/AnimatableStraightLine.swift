//
//  AnimatableStraightLine.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/5/24.
//

import SwiftUI

struct AnimatableStraightLine: Shape {

    var from: CGPoint
    var to: CGPoint

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
        min(xGap, 14)
        //        min(xGap, 12)
        //        min(xGap, 8)
    }

    var isForwardEdge: Bool {
        to.x > from.x
    }

    var xGap: CGFloat {
        (from.x - to.x).magnitude
    }

    var extendedFrom: CGPoint {
        let k = CGPoint(x: (from.x + (isForwardEdge ? extensionAmount : -extensionAmount)),
                        y: from.y)
        // print("extendedFrom: \(k)")
        return k
    }

    var extendedTo: CGPoint {
        let k = CGPoint(x: (to.x + (isForwardEdge ? -extensionAmount : extensionAmount)),
                        y: to.y)
        // print("extendedTo: \(k)")
        return k
    }

    func path(in _: CGRect) -> Path {
        Path { p in
            p.move(to: from)
            p.addLine(to: extendedFrom)
            p.addLine(to: extendedTo)
            p.addLine(to: to)
        }
    }
}

// struct StraightLineUtils {
//
//    static func isForwardEdge(to: CGPoint, from: CGPoint) -> Bool {
//        to.x > from.x
//    }
//
//    static func xGap(to: CGPoint, from: CGPoint) -> CGFloat {
//        (from.x - to.x).magnitude
//    }
//
//    static func extendedFrom(to: CGPoint, from: CGPoint) -> CGPoint {
//        let k = CGPoint(x: (from.x + (isForwardEdge ? extensionAmount : -extensionAmount)),
//                        y: from.y)
//        // print("extendedFrom: \(k)")
//        return k
//    }
//
//    static func extendedTo(to: CGPoint, from: CGPoint) -> CGPoint {
//        let k = CGPoint(x: (to.x + (isForwardEdge ? -extensionAmount : extensionAmount)),
//                        y: to.y)
//        // print("extendedTo: \(k)")
//        return k
//    }
// }
