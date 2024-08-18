//
//  PackNodeHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/11/23.
//

import Foundation
import StitchSchemaKit

struct PackNodeLocations {
    static let x: Int = 0
    static let y: Int = 1
    static let z: Int = 2
    static let w: Int = 3
}

struct PackNodeMatrixLocations {
    static let x: Int = 0
    static let y: Int = 1
    static let z: Int = 2
    static let scaleX: Int = 3
    static let scaleY: Int = 4
    static let scaleZ: Int = 5
    static let rotationX: Int = 6
    static let rotationY: Int = 7
    static let rotationZ: Int = 8
    static let rotationReal: Int = 9
}

// NOTE: NOT ACCURATE FOR SEPARATE PACK NODES FOR EACH SHAPE COMMAND TYPE
struct PackNodeShapeCommandLocations {
    static let commandType: Int = 0
    static let point: Int = 1
    static let curveFrom: Int = 2
    static let curveTo: Int = 3
}

// given two inputs that could both be either .number or .layerDimension,
// return a .position
extension StitchPosition {
    static func fromSizeNodeInputs(_ values: PortValues) -> StitchPosition {

        guard values.count == 2 else {
            fatalErrorIfDebug("StitchPosition.fromSizeNodeInputs: too many inputs")
            return .zero
        }

        if let x = values.first!.getNumber,
           let y = values[1].getNumber {
            return StitchPosition(x: x,
                                  y: y)
        } else if let x = values.first!.getLayerDimension,
                  let y = values[1].getLayerDimension {
            return StitchPosition(x: x.asNumber,
                                  y: y.asNumber)
        } else {
            fatalErrorIfDebug("StitchPosition.fromSizeNodeInputs: incorrect inputs")
            return .zero
        }
    }
}

extension LayerSize {
    static func fromSizeNodeInputs(_ values: PortValues) -> LayerSize {

        guard values.count == 2 else {
            fatalError("LayerSize.fromSizeNodeInputs: sizeOp: Incorrect number of inputs")
        }

        if let x = values.first!.getNumber,
           let y = values[1].getNumber {
            return LayerSize(width: x, height: y)
        } else if let x = values.first!.getLayerDimension,
                  let y = values[1].getLayerDimension {
            return LayerSize(width: x, height: y)
        } else {
            fatalErrorIfDebug("LayerSize.fromSizeNodeInputs: incorrect inputs")
            return .zero
        }
    }
}
