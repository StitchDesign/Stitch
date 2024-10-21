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
func numberCoercer(_ values: PortValues,
                    graphTime: TimeInterval) -> PortValues {
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
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .json, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .none:
            return coerceToTruthyOrFalsey(self,
                                          graphTime: graphTime)
            ? .numberDefaultTrue
            : .numberDefaultFalse
        }
    }
}

func layerDimensionCoercer(_ values: PortValues,
                           graphTime: TimeInterval) -> PortValues {
    values
        .map(\.coerceToLayerDimension)
        .map(PortValue.layerDimension)
}

extension PortValue {
    var coerceToLayerDimension: LayerDimension {
        
        let value = self
        
        // port-value to use if we cannot coerce the value
        // to a meaningful LayerDimension
        let defaultValue: LayerDimension = .number(
            coerceToTruthyOrFalsey(value,
                                   // graphTime irrelevant for non-pulse PortValues
                                   graphTime: .zero)
            ? 1.0
            : .zero)

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
func sizeCoercer(_ values: PortValues,
                 graphTime: TimeInterval) -> PortValues {
    
    return values.map { (value: PortValue) -> PortValue in
        
        let defaultValue = coerceToTruthyOrFalsey(value,
                                                  graphTime: graphTime)
        ? defaultPositionTrue
        : defaultPositionFalse
        
        switch value {
        case .size:
            return value
        case .number(let x):
            return .size(LayerSize(width: x,
                                   height: x))
        case .int(let x):
            return .size(CGSize(width: x,
                                height: x).toLayerSize)
        case .position(let x):
            return .size(LayerSize(width: x.x,
                                   height: x.y))
        case .layerDimension(let x):
            return .size(LayerSize(width: x.asNumber,
                                   height: x.asNumber))
        case .point3D(let x):
            return .size(LayerSize(width: x.x,
                                   height: x.y))
        case .point4D(let x):
            return .size(LayerSize(width: x.x,
                                   height: x.y))
        case .bool(let x):
            return .size(x ? .multiplicationIdentity : .zero)
        case .json(let x):
            return .size(x.value.toSize ?? .zero)
        case .string(let x):
            if let dimension = LayerDimension.fromUserEdit(edit: x.string) {
                return .size(LayerSize(width: dimension,
                                       height: dimension))
            }
            return defaultValue
            
        case .transform, .plane, .networkRequestType, .color, .pulse, .asyncMedia, .anchoring, .cameraDirection, .assignedLayer, .scrollMode, .textAlignment, .textVerticalAlignment, .fitStyle, .animationCurve, .lightType, .layerStroke, .textTransform, .dateAndTimeFormat, .shape, .scrollJumpStyle, .scrollDecelerationRate, .delayStyle, .shapeCoordinates, .shapeCommandType, .shapeCommand, .orientation, .cameraOrientation, .deviceOrientation, .vnImageCropOption, .textDecoration, .textFont, .blendMode, .mapType, .progressIndicatorStyle, .mobileHapticStyle, .strokeLineCap, .strokeLineJoin, .contentMode, .sizingScenario, .pinTo, .deviceAppearance, .materialThickness, .none:
            return defaultValue
        case .comparable(_):
            <#code#>
        case .spacing(_):
            <#code#>
        case .padding(_):
            <#code#>
        }
    }
}
