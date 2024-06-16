//
//  CurveLineView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/9/24.
//

import SwiftUI

struct CurveLine: Shape {

    var from: CGPoint
    var to: CGPoint

    //    let extensionAmount: CGFloat = 36
    //    let extensionAmount: CGFloat = 18
    //    let extensionAmount: CGFloat = 8

    var extensionAmount: CGFloat {
        //        min(xGap, 36)
        //        min(xGap, 18)
        //        min(xGap, 8)
        min(xGap, 12) // does this help with the "slight mismatch" ?
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

        let k = CGPoint(
            //            x: (from.x + (isForwardEdge ? extensionAmount : -extensionAmount)).rounded(.up),
            //            y: from.y.rounded(.up)

            x: (from.x + (isForwardEdge ? extensionAmount : -extensionAmount)).rounded(.up),
            y: from.y
        )

        //        // print("extendedFrom: \(k)")
        return k
    }

    var extendedTo: CGPoint {

        //        let k = CGPoint(x: to.x + (isForwardEdge ? -extensionAmount : extensionAmount),
        //                        y: to.y)

        let k = CGPoint(
            x: (to.x + (isForwardEdge ? -extensionAmount : extensionAmount)).rounded(.up),
            y: to.y
        )
        //        // print("extendedTo: \(k)")
        return k
    }

    var control1: CGPoint {
        //        let k = CGPoint(x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2),
        //                        y: extendedFrom.y)

        let k = CGPoint(
            //            x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2).rounded(.up),
            //            y: extendedFrom.y.rounded(.up)

            x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2).rounded(.up),
            y: extendedFrom.y
        )

        // print("control1: \(k)")
        return k
    }

    var control2: CGPoint {
        //        let k = CGPoint(x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2),
        //                        y: extendedTo.y)

        let k = CGPoint(
            //            x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2).rounded(.up),
            //            y: extendedTo.y.rounded(.up)
            x: extendedFrom.x + ((extendedTo.x - extendedFrom.x)/2).rounded(.up),
            y: extendedTo.y
        )

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
