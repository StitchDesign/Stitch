//
//  ShapeAndRect.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ShapeAndRect {

    // for centering inside the union
    func yOffsetBy(_ smallestShape: CGSize) -> CGFloat {
        switch self {
        case .triangle, .custom:
            return smallestShape.height.abs/2
        case .oval, .circle, .rectangle:
            // Regular shapes always move left and up
            return (smallestShape.height.abs - self.rect.height.abs)/2
        }
    }

    // for centering inside the union
    func xOffsetBy(_ smallestShape: CGSize) -> CGFloat {
        switch self {
        case .triangle, .custom:
            // Custom path-drawn shapes always move right and down
            return smallestShape.width.abs/2
        case .oval, .circle, .rectangle:
            // Regular shapes always move left and up
            return (smallestShape.width.abs - self.rect.width.abs)/2
        }
    }
}

// Methods for combining shapes (see `Shape Union` node)
extension CGFloat {
    var abs: CGFloat {
        Swift.abs(self)
    }
}

extension [CGRect] {
    func largestNorthGain(_ baseOriginY: CGFloat = 0,
                          _ baseHeight: CGFloat = 100) -> CGFloat {
        self.min { rect1, rect2 in
            rect1.yBound(baseOriginY,
                         baseHeight,
                         isNorth: true) < rect2.yBound(baseOriginY,
                                                       baseHeight,
                                                       isNorth: true)
        }?.yBound(baseOriginY, baseHeight, isNorth: true) ?? 0
    }

    func largestSouthGain(_ baseOriginY: CGFloat,
                          _ baseHeight: CGFloat) -> CGFloat {
        self.max { rect1, rect2 in
            rect1.yBound(baseOriginY, baseHeight) < rect2.yBound(baseOriginY, baseHeight)
        }?.yBound(baseOriginY, baseHeight) ?? 0
    }

    func largestWestGain(_ baseOriginX: CGFloat,
                         _ baseWidth: CGFloat) -> CGFloat {
        self.min { rect1, rect2 in
            rect1.xBound(baseOriginX, baseWidth, isWest: true) < rect2.xBound(baseOriginX, baseWidth, isWest: true)
        }?.xBound(baseOriginX, baseWidth, isWest: true) ?? 0
    }

    func largestEastGain(_ baseOriginX: CGFloat,
                         _ baseWidth: CGFloat) -> CGFloat {
        self.max { rect1, rect2 in
            rect1.xBound(baseOriginX, baseWidth) < rect2.xBound(baseOriginX, baseWidth)
        }?.xBound(baseOriginX, baseWidth) ?? 0
    }

}
