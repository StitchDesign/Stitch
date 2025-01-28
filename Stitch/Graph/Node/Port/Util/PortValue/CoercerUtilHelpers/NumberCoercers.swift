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
import SwiftyJSON


// MARK: INT

// TODO: `int` is a legacy PortValue.type to be removed ?
func intCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    return values.map { (value: PortValue) -> PortValue in
        switch value {
        case .int:
            return value
        default:
            return value.coerceToTruthyOrFalsey(graphTime) ? intDefaultTrue : intDefaultFalse
        }
    }
}



// MARK: NUMBER

// e.g. a PortValue.number-type input is receiving a new list of values, which may need to be duck-typed to PortValue.number
func numberCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .number($0.toNumber(graphTime)) }
}

// i.e. some PortValue is flowing into a PortValue.number type input
extension PortValue {
    
    // Return PortValue, or the more specific type?
    func toNumber(_ graphTime: TimeInterval) -> Double {
        
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
        case .json(let x):
            let json: JSON = x.value
            // log("toNumber: json \(json)")
            if let n = json.double {
                // log("toNumber: n \(n)")
                return n
            } else {
                return self.coerceToTruthyOrFalsey(graphTime) ? .numberDefaultTrue : .numberDefaultFalse
            }
            
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .none:
            return self.coerceToTruthyOrFalsey(graphTime) ? .numberDefaultTrue : .numberDefaultFalse
        }
    }
}


// MARK: LAYER DIMENSION

func layerDimensionCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .layerDimension($0.coerceToLayerDimension(graphTime)) }
}

extension PortValue {
    func coerceToLayerDimension(_ graphTime: TimeInterval) -> LayerDimension {
        
        let value = self
        
        // port-value to use if we cannot coerce the value
        // to a meaningful LayerDimension
        let defaultValue: LayerDimension = .number(value.coerceToTruthyOrFalsey(graphTime) ? 1.0 : .zero)

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

        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .json, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .none:
            return defaultValue
        }
    }
}


// MARK: SIZE

// Takes a PortValue; returns a .size PortValue
func sizeCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .size($0.coerceToSize(graphTime)) }
}

extension PortValue {
    func coerceToSize(_ graphTime: TimeInterval) -> LayerSize {
        let defaultValue: LayerSize = self.coerceToTruthyOrFalsey(graphTime) ? .defaultTrue : .defaultFalse
        
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
            
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .none:
            return defaultValue
        }
    }
}



// MARK: POSITION

func positionCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .position($0.coerceToPosition(graphTime)) }
}

extension PortValue {
    func coerceToPosition(_ graphTime: TimeInterval) -> StitchPosition {
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
            
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .none:
            return value.coerceToTruthyOrFalsey(graphTime) ? .defaultTrue : .defaultFalse
        }
    }
}


// MARK: POINT3D

// Better: break down into a function like:
// `(PortValue) -> Point3D` + `Point3D -> PortValue.point3D`
// (Note: most useful for an associated data that is unique across port values.)
func point3DCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .point3D($0.coerceToPoint3D(graphTime)) }
}

extension PortValue {
    func coerceToPoint3D(_ graphTime: TimeInterval) -> Point3D {
        switch self {
        case .point3D(let x):
            return x
        case .number(let x):
            return x.toPoint3D
        case .int(let x):
            return x.toPoint3D
        case .size(let x):
            return x.asAlgebraicCGSize.toPoint3D
        case .position(let x):
            return x.toPoint3D
        case .point4D(let x):
            return x.toPoint3D
        case .json(let x):
            return x.value.toPoint3D ?? .zero
        case .bool(let x):
            return x ? .multiplicationIdentity : .zero
        case .layerDimension(let x):
            return .fromSingleNumber(x.asNumber)
        case .spacing(let x):
            return .fromSingleNumber(x.asNumber)
        case .padding(let x):
            return .fromSingleNumber(x.asNumber)
        case .string(let x):
            if let dimension = Stitch.toNumber(x.string) {
                return .fromSingleNumber(dimension)
            }
            return .defaultTrue
            
        // TODO: how to better handle this `PortValue.comparable` type?
        case .comparable(let x):
            if let x = x {
                switch x {
                case .number(let k):
                    return .fromSingleNumber(k)
                case .string(let k):
                    if let dimension = Stitch.toNumber(x.string) {
                        return .fromSingleNumber(dimension)
                    }
                    return .defaultTrue
                case .bool(let k):
                    return k ? .multiplicationIdentity : .zero
                }
            }
            return .defaultFalse
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .none:
            return self.coerceToTruthyOrFalsey(graphTime) ? Point3D.multiplicationIdentity : .zero
        }
    }
}

// MARK: POINT4D

func point4DCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .point4D($0.coerceToPoint4D(graphTime)) }
}

extension PortValue {
    func coerceToPoint4D(_ graphTime: TimeInterval) -> Point4D {
        switch self {
        case .point4D(let x):
            return x
        case .number(let x):
            return x.toPoint4D
        case .int(let x):
            return x.toPoint4D
        case .size(let x):
            return x.asAlgebraicCGSize.toPoint4D
        case .position(let x):
            return x.toPoint4D
        case .point3D(let x):
            return x.toPoint4D
        case .json(let x):
            return x.value.toPoint4D ?? .empty
        case .bool(let x):
            return x ? .multiplicationIdentity : .zero
        case .layerDimension(let x):
            return .fromSingleNumber(x.asNumber)
        case .spacing(let x):
            return .fromSingleNumber(x.asNumber)
        case .padding(let x):
            return .fromSingleNumber(x.asNumber)
        case .string(let x):
            if let dimension = Stitch.toNumber(x.string) {
                return .fromSingleNumber(dimension)
            }
            return .defaultTrue
            
        // TODO: how to better handle this `PortValue.comparable` type?
        case .comparable(let x):
            if let x = x {
                switch x {
                case .number(let k):
                    return .fromSingleNumber(k)
                case .string(let k):
                    if let dimension = Stitch.toNumber(x.string) {
                        return .fromSingleNumber(dimension)
                    }
                    return .defaultTrue
                case .bool(let k):
                    return k ? .multiplicationIdentity : .zero
                }
            }
            return .defaultFalse
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .none:
            return self.coerceToTruthyOrFalsey(graphTime) ? .multiplicationIdentity : .empty
        }
    }
}

// MARK: SPACING

func spacingCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values
        .map { .spacing($0.coerceToStitchSpacing(graphTime)) }
}

extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToStitchSpacing(_ graphTime: TimeInterval) -> StitchSpacing {
        switch self {
        case .number(let x):
            return .fromSingleNumber(x)
        case .int(let x):
            return .fromSingleNumber(Double(x))
        case .size(let x):
            let x = x.asAlgebraicCGSize
            return .fromSingleNumber(x.width)
        case .position(let x):
            return .fromSingleNumber(x.x)
        case .point3D(let x):
            return .fromSingleNumber(x.x)
        case .point4D(let x):
            return .fromSingleNumber(x.x)
            
            // TODO: get clever here?
//        case .json(let x):
//            let x = x.value.toPoint4D
            
        case .bool(let x):
            return x ? .defaultTrue : .defaultFalse
        
        case .layerDimension(let x):
            return .fromSingleNumber(x.asNumber)
        
        case .spacing(let x):
            return x
        
        case .padding(let x):
            return .fromSingleNumber(x.asNumber)
        
        case .string(let x):
            if let dimension = Stitch.toNumber(x.string) {
                return .fromSingleNumber(dimension)
            }
            return .defaultFalse
            
            // TODO: how to better handle this `PortValue.comparable` type?
        case .comparable(let x):
            if let x = x {
                switch x {
                case .number(let k):
                    return .fromSingleNumber(k)
                case .string(let k):
                    if let dimension = Stitch.toNumber(x.string) {
                        return .fromSingleNumber(dimension)
                    }
                    return .defaultTrue
                case .bool(let k):
                    return k ? .defaultTrue : .defaultFalse
                }
            }
            return .defaultFalse
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .anchorEntity, .json, .none:
            return self.coerceToTruthyOrFalsey(graphTime) ? .defaultTrue : .defaultFalse
        }
        
    }
}


extension StitchSpacing {
    var asNumber: CGFloat {
        switch self {
        case .number(let x):
            return x
        case .between, .evenly:
            return 1
        }
    }
    
    static func fromSingleNumber(_ n: Double) -> Self {
        .number(n)
    }
    
    static let defaultTrue: Self = .evenly
    static let defaultFalse: Self = .number(0)
}


// MARK: PADDING

func paddingCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .padding($0.coerceToStitchPadding(graphTime)) }
}


extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToStitchPadding(_ graphTime: TimeInterval) -> StitchPadding {
        switch self {
        case .number(let x):
            return .fromSingleNumber(x)
        case .int(let x):
            return .fromSingleNumber(Double(x))
        case .size(let x):
            let x = x.asAlgebraicCGSize
            return .init(top: x.height, right: x.width, bottom: x.height, left: x.width)
        case .position(let x):
            return .init(top: x.y, right: x.x, bottom: x.y, left: x.x)
        case .point3D(let x):
            return .init(top: x.x, right: x.y, bottom: x.z, left: x.x)
        case .point4D(let x):
            return .init(top: x.x, right: x.y, bottom: x.z, left: x.w)
            
            // TODO: get clever here?
//        case .json(let x):
//            let x = x.value.toPoint4D
            
        case .bool(let x):
            return x ? .multiplicationIdentity : .zero
        
        case .layerDimension(let x):
            return .fromSingleNumber(x.asNumber)
        
        case .spacing(let x):
            return .fromSingleNumber(x.asNumber)
        
        case .padding(let x):
            return x
        
        case .string(let x):
            if let dimension = Stitch.toNumber(x.string) {
                return .fromSingleNumber(dimension)
            }
            return .defaultFalse
            
            // TODO: how to better handle this `PortValue.comparable` type?
        case .comparable(let x):
            if let x = x {
                switch x {
                case .number(let k):
                    return .fromSingleNumber(k)
                case .string(let k):
                    if let dimension = Stitch.toNumber(x.string) {
                        return .fromSingleNumber(dimension)
                    }
                    return .defaultTrue
                case .bool(let k):
                    return k ? .defaultTrue : .defaultFalse
                }
            }
            return .defaultFalse
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .json, .anchorEntity, .none:
            return self.coerceToTruthyOrFalsey(graphTime) ? .multiplicationIdentity : .empty
        }
    }
}

extension StitchPadding {
    var asNumber: CGFloat {
        self.top
    }
    
    static func fromSingleNumber(_ n: Double) -> Self {
        .init(top: n, right: n, bottom: n, left: n)
    }
    
    static let defaultTrue: Self = .init(top: 1, right: 1, bottom: 1, left: 1)
    static let defaultFalse: Self = .init(top: 0, right: 0, bottom: 0, left: 0)
    
    static let multiplicationIdentity: Self = Self.defaultTrue
    static let empty = Self.defaultFalse
}

