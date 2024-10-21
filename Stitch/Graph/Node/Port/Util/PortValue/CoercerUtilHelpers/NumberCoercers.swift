//
//  CoercerHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/21/24.
//

// MARK: COERCERS FOR NUMBER-LIKE PortValue TYPES, e.g. .number, .padding, .point3D

import Foundation
import StitchSchemaKit
import SwiftUI

// e.g. a PortValue.number-type input is receiving a new list of values, which may need to be duck-typed to PortValue.number
func numberCoercer(_ values: PortValues) -> PortValues {
    values.map { .number($0.toNumber) }
}

// i.e. some PortValue is flowing into a PortValue.number type input
extension PortValue {
    
    // Return PortValue, or the more specific type?
    var toNumber: Double {
        
        switch self {
            
        // Number-like types
        case .number(let x):
            return x
        case .int(let x):
            return Double(x)
        case .layerDimension(let x):
            return x.asNumber
        case .size(let x):
            return x.width.asNumber
        case .position(let x):
            return x.x
        case .point3D(let x):
            return x.x
        case .point4D(let x):
            return x.x
        case .spacing(let x):
            return x.asNumber
        case .padding(let x):
            return x.asNumber
        case .bool(let x):
            return x ? .multiplicationIdentity : .zero
        case .comparable(let x):
            if let x = x {
                return x.number
            }
            return .numberDefaultFalse
        case .string(let x):
            if let number = Double(x.string) {
                return number
            } else if x.string.isEmpty {
                return .numberDefaultFalse
            } else {
                return .numberDefaultTrue
            }
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .json, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .none:
            return self.coerceToTruthyOrFalsey() ? .numberDefaultTrue : .numberDefaultFalse
        }
    }
}

func layerDimensionCoercer(_ values: PortValues) -> PortValues {
    values.map { .layerDimension($0.coerceToLayerDimension) }
}

extension PortValue {
    var coerceToLayerDimension: LayerDimension {
        
        let value = self
        
        // port-value to use if we cannot coerce the value
        // to a meaningful LayerDimension
        let defaultValue: LayerDimension = .number(value.coerceToTruthyOrFalsey() ? 1.0 : .zero)

        switch value {

        // If value is already a layer dimension,
        // then just return it.
        case .layerDimension(let x):
            return x

        case .int(let x):
            return LayerDimension.number(CGFloat(x))
            
        // If value is a number,
        // wrap it in a regular number.
        case .number(let x):
            return LayerDimension.number(x)

        // If we passed in a size, just grab the width?
        case .size(let x):
            return x.width
            
        // If we passed in a position, just grab the x?
        case .position(let x):
            return LayerDimension.number(x.x)
        case .point3D(let x):
            return LayerDimension.number(x.x)
        case .point4D(let x):
            return LayerDimension.number(x.x)
        case .spacing(let x):
            return LayerDimension.number(x.asNumber)
        case .padding(let x):
            return LayerDimension.number(x.asNumber)
        case .bool(let x):
            return LayerDimension.number(x ? Double.multiplicationIdentity : .zero)
        
        case .comparable(let x):
            if let x = x {
                return .number(x.number)
            }
            return .number(Double.numberDefaultFalse)
            
        // If a string, try to parse to a layer-dimension.
        case .string(let x):
            return LayerDimension.fromUserEdit(edit: x.string) ?? defaultValue

        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .json, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .none:
            return defaultValue
        }
    }
}


// Takes a PortValue; returns a .size PortValue
func sizeCoercer(_ values: PortValues) -> PortValues {
    values.map { .size($0.coerceToSize) }
}

extension PortValue {
    var coerceToSize: LayerSize {
        let defaultValue: LayerSize = self.coerceToTruthyOrFalsey() ? .defaultTrue : .defaultFalse
        
        switch self {
        case .size(let x):
            return x
        case .number(let x):
            return LayerSize(width: x, height: x)
        case .int(let x):
            return CGSize(width: x, height: x).toLayerSize
        case .position(let x):
            return LayerSize(width: x.x, height: x.y)
        case .layerDimension(let x):
            return LayerSize(width: x.asNumber, height: x.asNumber)
        case .point3D(let x):
            return LayerSize(width: x.x, height: x.y)
        case .point4D(let x):
            return LayerSize(width: x.x,  height: x.y)
        case .bool(let x):
            return x ? .multiplicationIdentity : .zero
        case .json(let x):
            return x.value.toSize ?? .zero
        
        case .spacing(let x):
            return .init(width: x.asNumber, height: x.asNumber)
        case .padding(let x):
            return .init(width: x.top, height: x.bottom)
            
        // TODO: how to better handle this `PortValue.comparable` type?
        case .comparable(let x):
            if let x = x {
                switch x {
                case .number(let k):
                    return .init(width: k, height: k)
                case .string(let k):
                    if let dimension = LayerDimension.fromUserEdit(edit: k.string) {
                        return LayerSize(width: dimension, height: dimension)
                    }
                    return defaultValue
                case .bool(let k):
                    return k ? .multiplicationIdentity : .zero
                }
            }
            return .defaultFalse
            
        case .string(let x):
            if let dimension = LayerDimension.fromUserEdit(edit: x.string) {
                return LayerSize(width: dimension, height: dimension)
            }
            return defaultValue
            
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .none:
            return defaultValue
        }
    }
}

extension PortValue {
    var coerceToPosition: StitchPosition {
        let value = self
        
        switch value {
        case .position(let x):
            return x
        case .number(let x):
            return x.toStitchPosition
        case .size(let x):
            return x.asAlgebraicCGSize.toCGPoint
        case .layerDimension(let x):
            return StitchPosition(x: x.asNumber, y: x.asNumber)
        case .int(let x):
            return x.toStitchPosition
        case .point3D(let x):
            return x.toStitchPosition
        case .point4D(let x):
            return x.toStitchPosition
        case .json(let x):
            return x.value.toStitchPosition ?? .defaultFalse
        case .bool(let x):
            return x ? .multiplicationIdentity : .zero
        case .spacing(let x):
            return .init(x: x.asNumber, y: x.asNumber)
        case .padding(let x):
            return .init(x: x.top, y: x.bottom)
        case .string(let x):
            if let dimension = Stitch.toNumber(x.string) {
                return .init(x: dimension, y: dimension)
            }
            return .defaultTrue
            
        // TODO: how to better handle this `PortValue.comparable` type?
        case .comparable(let x):
            if let x = x {
                switch x {
                case .number(let k):
                    return .init(x: k, y: k)
                case .string(let k):
                    if let dimension = Stitch.toNumber(x.string) {
                        return .init(x: dimension, y: dimension)
                    }
                    return .defaultTrue
                case .bool(let k):
                    return k ? .multiplicationIdentity : .zero
                }
            }
            return .defaultFalse
            
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .none:
            return value.coerceToTruthyOrFalsey() ? .defaultTrue : .defaultFalse
        }
    }
}
                
func positionCoercer(_ values: PortValues) -> PortValues {
    values.map { .position($0.coerceToPosition) }
}

// Better: break down into a function like:
// `(PortValue) -> Point3D` + `Point3D -> PortValue.point3D`
// (Note: most useful for an associated data that is unique across port values.)
func point3DCoercer(_ values: PortValues,
                    graphTime: TimeInterval) -> PortValues {

    return values.map { (value: PortValue) -> PortValue in
        var k: Point3D
        switch value {
        case .point3D(let x):
            k = x
        case .number(let x):
            k = x.toPoint3D
        case .int(let x):
            k = x.toPoint3D
        case .size(let x):
            k = x.asAlgebraicCGSize.toPoint3D
        case .position(let x):
            k = x.toPoint3D
        case .point4D(let x):
            k = x.toPoint3D
        case .json(let x):
            k = x.value.toPoint3D ?? .zero
        case .bool(let x):
            return .point3D(x ? .multiplicationIdentity : .zero)
        default:
            k = coerceToTruthyOrFalsey(value, graphTime: graphTime) ? Point3D.multiplicationIdentity : .zero
        }
        return .point3D(k)
    }
}

func point4DCoercer(_ values: PortValues,
                    graphTime: TimeInterval) -> PortValues {
    return values.map { (value: PortValue) -> PortValue in
        switch value {
        case .point4D(let x):
            return .point4D(x)
        case .number(let x):
            return .point4D(x.toPoint4D)
        case .int(let x):
            return .point4D(x.toPoint4D)
        case .size(let x):
            return .point4D(x.asAlgebraicCGSize.toPoint4D)
        case .position(let x):
            return .point4D(x.toPoint4D)
        case .point3D(let x):
            return .point4D(x.toPoint4D)
        case .json(let x):
            return .point4D(x.value.toPoint4D ?? .empty)
        case .bool(let x):
            return .point4D(x ? .multiplicationIdentity : .zero)
        default:
            return .point4D(
                coerceToTruthyOrFalsey(value, graphTime: graphTime) ? .multiplicationIdentity : .empty
            )
        }
    }
}
