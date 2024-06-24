//
//  CGPointUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/9/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias CGPoints = [CGPoint]

// Given a series of points, eg composing a triangle or pentagon,
// we can determine the resulting bounding box that contains the points.
// Similar to the `CGRect` in SwiftUI Shape protocol's `path(in rect: CGRect)`.
extension CGPoints {
    var boundingBox: CGSize {
        .init(width: self.boundingBoxWidth,
              height: self.boundingBoxHeight)
    }
}

extension CGPoint {
    var toCGSize: CGSize {
        CGSize(width: self.x, height: self.y)
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x,
             y: lhs.y + rhs.y)
    }

    static func += (lhs: inout Self, rhs: Self) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x,
             y: lhs.y - rhs.y)
    }

    static func -= (lhs: inout Self, rhs: Self) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x * rhs.x,
             y: lhs.y * rhs.y)
    }

    static func + (lhs: Self, rhs: CGFloat) -> Self {
        Self(x: lhs.x + rhs,
             y: lhs.y + rhs)
    }

    static func - (lhs: Self, rhs: CGFloat) -> Self {
        Self(x: lhs.x - rhs,
             y: lhs.y - rhs)
    }

    static func / (lhs: Self, rhs: CGFloat) -> Self {
        Self(x: lhs.x / rhs,
             y: lhs.y / rhs)
    }
}

extension CGPoint {
    func scaleBy(_ amount: CGFloat) -> CGPoint {
        CGPoint(x: self.x * amount,
                y: self.y * amount)
    }
}
