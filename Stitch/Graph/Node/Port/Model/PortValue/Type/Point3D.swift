//
//  Point3D.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Point3D {
    static let zero = Point3D(x: 0, y: 0, z: 0)
    static let nonZero = Point3D(x: 1, y: 1, z: 1)

    static let multiplicationIdentity = Self.nonZero
    static let additionIdentity = Self.zero
    static let empty = Self.zero
}

extension Point3D {

    var toStitchPosition: StitchPosition {
        .init(width: self.x, height: self.y)
    }

    var toPoint4D: Point4D {
        .init(x: self.x, y: self.y, z: self.z, w: .zero)
    }

    static func - (lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x - rhs.x,
                y: lhs.y - rhs.y,
                z: lhs.z - rhs.z)
    }

    static func + (lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x + rhs.x,
                y: lhs.y + rhs.y,
                z: lhs.z + rhs.z)
    }

    static func += (lhs: inout Point3D, rhs: Point3D) {
        lhs.x += rhs.x
        lhs.y += rhs.y
        lhs.z += rhs.z
    }

    static func -= (lhs: inout Point3D, rhs: Point3D) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        lhs.z -= rhs.z
    }

    static func * (lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x * rhs.x,
                y: lhs.y * rhs.y,
                z: lhs.z * rhs.z)
    }

    // NOT USEFUL SINCE WE NEED TO USE ZERO-COMPATIBLE DIVISION
    //    static func / (lhs: Point3D, rhs: Point3D) -> Point3D {
    //        Point3D(x: lhs.x / rhs.x,
    //                y: lhs.y / rhs.y,
    //                z: lhs.z / rhs.z)
    //    }

}
