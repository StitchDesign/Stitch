//
//  ExpansionBox.swift
//  prototype
//
//  Created by Christian J Clampitt on 12/7/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ExpansionBox: Equatable, Codable, Hashable {

    var expansionDirection: ExpansionDirection = .none

    // size is always positive numbers
    var size: CGSize = .zero

    // drag gesture start
    var startPoint: CGPoint = .zero

    // drag gesture current
    var endPoint: CGPoint = .zero

    var asCGRect: CGRect {
        // origin will be halfway on the line
        // between the starting point and ending point
        // https://www.mathsisfun.com/algebra/line-midpoint.html
        let y = (endPoint.y + startPoint.y) / 2
        let x = (endPoint.x + startPoint.x) / 2
        let mid = CGPoint(x: x, y: y)

        //        log("asCGRect: expansionDirection: \(expansionDirection)")
        //        log("asCGRect: size: \(size)")
        //        log("asCGRect: startPoint: \(startPoint)")
        //        log("asCGRect: endPoint: \(endPoint)")
        //        log("asCGRect: mid: \(mid)")

        return CGRect(origin: mid, size: size)
    }

    // active corner is always just the startPoint?
    // or need to adjust further?

    // need to know in which direction we're expanding
    var anchorCorner: CGPoint {

        // eg if we're expanding down and to the right,
        // then we
        switch expansionDirection {

        case .topLeft:
            return CGPoint(x: startPoint.x - size.width/2,
                           y: startPoint.y - size.height/2)

        case .topRight:
            return CGPoint(x: startPoint.x + size.width/2,
                           y: startPoint.y - size.height/2)

        case .bottomLeft:
            return CGPoint(x: startPoint.x - size.width/2,
                           y: startPoint.y + size.height/2)

        case .bottomRight:
            return CGPoint(x: startPoint.x + size.width/2,
                           y: startPoint.y + size.height/2)

        case .none:
            return startPoint
        }
    }
}
