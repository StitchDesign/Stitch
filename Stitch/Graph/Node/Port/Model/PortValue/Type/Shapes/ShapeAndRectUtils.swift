//
//  ShapeAndRectUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

// A non-empty list of ShapeAndRect is what any shape patch node outputs
// (whether e.g. triangle shape patch node or union shape patch node).
extension ShapeAndRect {
    // Just the raw, base shape itself
    var shape: any Shape {
        switch self {
        case .oval:
            return Ellipse()
        case .circle:
            return Circle() // same as Ellipse?
        case .rectangle(let x):
            return RoundedRectangle(cornerRadius: x.cornerRadius)
        case .triangle(let trianglePoints):
            // need to handle this better
            return Triangle(p1: trianglePoints.p1,
                            p2: trianglePoints.p2,
                            p3: trianglePoints.p3)
        case .custom(let commands):
            return JSONCustomShape(jsonCommands: commands)
        }
    }

    var getCustom: JSONShapeCommands? {
        switch self {
        case .custom(let x):
            return x
        default:
            return nil
        }
    }
}
