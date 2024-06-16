//
//  StraightLineView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/9/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct StraightLine: Shape {

    var from: CGPoint
    var to: CGPoint

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
