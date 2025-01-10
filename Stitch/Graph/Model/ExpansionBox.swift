//
//  ExpansionBox.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ExpansionBox: Equatable {

    var expansionDirection: ExpansionDirection = .none

    // size is always positive numbers
    var size: CGSize = .zero

    // drag gesture start
    var startPoint: CGPoint = .zero

    // drag gesture current
    var endPoint: CGPoint = .zero

    var asCGRect: CGRect {
        let size = CGSize(width: endPoint.x - startPoint.x,
                          height: endPoint.y - startPoint.y)
        return .init(origin: startPoint, size: size)
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
