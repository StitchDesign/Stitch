//
//  PositionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias StitchPosition = CGPoint

extension CGPoint {
    var toPoint3D: Point3D {
        .init(x: self.x, y: self.y, z: .zero)
    }

    var toPoint4D: Point4D {
        .init(x: self.x, y: self.y, z: .zero, w: .zero)
    }
    
    static let multiplicationIdentity: Self = .init(x: 1, y: 1)
    static let additionIdentity: Self = .zero
}

/* ----------------------------------------------------------------
 CGSize helpers
 ---------------------------------------------------------------- */

let nonZeroCGSize: CGSize = CGSize(width: 1, height: 1)

// // https://www.swiftbysundell.com/articles/custom-operators-in-swift/
// Multiplying or dividing a size by a float;
// Adding or subtracting two sizes
extension CGSize {

    static let multiplicationIdentity: Self = nonZeroCGSize
    static let additionIdentity: Self = .zero

    // Multiplying vector by scalar

    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs,
               height: lhs.height * rhs)
    }

    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width / rhs,
               height: lhs.height / rhs)
    }

    var toPoint3D: Point3D {
        .init(x: self.width, y: self.height, z: .zero)
    }

    var toPoint4D: Point4D {
        .init(x: self.width, y: self.height, z: .zero, w: .zero)
    }

    // Inline operations between two vectors

    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width - rhs.width,
               height: lhs.height - rhs.height)
    }

    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width,
               height: lhs.height + rhs.height)
    }

    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs.width += rhs.width
        lhs.height += rhs.height
    }

    static func -= (lhs: inout CGSize, rhs: CGSize) {
        lhs.width -= rhs.width
        lhs.height -= rhs.height
    }

    static func * (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width * rhs.width,
               height: lhs.height * rhs.height)
    }

    // NOT USEFUL SINCE WE NEED ZERO-COMPATIBLE DIVISION
    //    static func / (lhs: CGSize, rhs: CGSize) -> CGSize {
    //        CGSize(width: lhs.width / rhs.width,
    //               height: lhs.height / rhs.height)
    //    }
}

extension CGSize {
    // new copy with original values + adjustment
    func update(width: CGFloat? = nil,
                height: CGFloat? = nil) -> CGSize {
        CGSize(width: self.width + (width ?? 0),
               height: self.height + (height ?? 0))
    }
}

extension InteractiveLayer {
    @MainActor
    func getDraggedPosition(startingPoint: CGPoint) -> CGPoint {
        .init(
            x: self.dragTranslation.width + startingPoint.x,
            y: self.dragTranslation.height + startingPoint.y)
    }
}

func updatePosition(position: CGPoint, offset: CGPoint) -> CGPoint {
    CGPoint(x: offset.x + position.x,
            y: offset.y + position.y)
}

func updatePosition(position: CGPoint,
                    width: CGFloat = .zero,
                    height: CGFloat = .zero) -> CGPoint {

    .init(x: width + position.x,
          y: height + position.y)
}

// TODO: remove when we're probably using CGPoint instead of CGSize for node size
extension CGSize {
    var toCGPoint: CGPoint {
        CGPoint(x: self.width, y: self.height)
    }

    func scaleBy(_ amount: CGFloat) -> CGSize {
        CGSize(width: self.width * amount,
               height: self.height * amount)
    }
}
