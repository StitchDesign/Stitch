//
//  HoleShapeMaskView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import NonEmpty

// https://stackoverflow.com/a/59659733/7170123
func holeShapeMask(shapes: [ShapeAndRect],
                   smallestShape: CGSize) -> Path {

    guard let shape1 = shapes.first else {
        log("holeShapeMask error: no shape found.")
        return .init()
    }

    var shape = shape1.shape
        .path(in: shape1.rect)
        .offsetBy(dx: shape1.xOffsetBy(smallestShape),
                  dy: shape1.yOffsetBy(smallestShape))

    guard shapes.count > 1 else {
        return shape
    }

    shapes.suffix(from: 1).forEach {
        shape.addPath($0.shape
                        .path(in: $0.rect)
                        .offsetBy(dx: $0.xOffsetBy(smallestShape),
                                  dy: $0.yOffsetBy(smallestShape)))
    }

    return shape
}
