//
//  Point4D.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/29/22.
//

import Foundation
import StitchSchemaKit

import SwiftUI

extension Point4D {
    static let zero = Point4D(x: 0, y: 0, z: 0, w: 0)
    static let nonZero = Point4D(x: 1, y: 1, z: 1, w: 1)

    static let multiplicationIdentity = Self.nonZero
    static let additionIdentity = Self.zero
    static let empty = Self.zero
}

extension Point4D {

    var toStitchPosition: StitchPosition {
        .init(x: self.x, y: self.y)
    }

    var toPoint3D: Point3D {
        .init(x: self.x, y: self.y, z: self.z)
    }

    static func - (lhs: Point4D, rhs: Point4D) -> Point4D {
        Point4D(x: lhs.x - rhs.x,
                y: lhs.y - rhs.y,
                z: lhs.z - rhs.z,
                w: lhs.w - rhs.w)
    }

    static func + (lhs: Point4D, rhs: Point4D) -> Point4D {
        Point4D(x: lhs.x + rhs.x,
                y: lhs.y + rhs.y,
                z: lhs.z + rhs.z,
                w: lhs.w + rhs.w)
    }

    static func += (lhs: inout Point4D, rhs: Point4D) {
        lhs.x += rhs.x
        lhs.y += rhs.y
        lhs.z += rhs.z
        lhs.w += rhs.w
    }

    static func -= (lhs: inout Point4D, rhs: Point4D) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        lhs.z -= rhs.z
        lhs.w -= rhs.w
    }

    static func * (lhs: Point4D, rhs: Point4D) -> Point4D {
        Point4D(x: lhs.x * rhs.x,
                y: lhs.y * rhs.y,
                z: lhs.z * rhs.z,
                w: lhs.w * rhs.w)
    }
}
