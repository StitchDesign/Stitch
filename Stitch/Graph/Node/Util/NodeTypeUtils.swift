//
//  UserVisibleType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 User-visible types: what the user sees
 ---------------------------------------------------------------- */

typealias NodeType = UserVisibleType

extension UserVisibleType {
    var display: String {
        switch self {
        case .string:
            return "Text"
        case .bool:
            return "Bool"
        case .int:
            return "Int"
        case .color:
            return "Color"
        case .number:
            return "Number"
        case .layerDimension:
            return "Layer Dimension"
        case .size:
            return "Size"
        case .position:
            return "Position"
        case .point3D:
            return "3D Point"
        case .point4D:
            return "4D Point"
        case .transform:
            return "Transform"
        case .plane:
            return "Plane"
        case .pulse:
            return "Pulse"
        case .media:
            return "Media"
        case .json:
            return "JSON"
        case .networkRequestType:
            return "Network Request Type"
        case .none:
            return "None"
        case .anchoring:
            return "Anchor"
        case .cameraDirection:
            return "Camera Direction"
        case .interactionId:
            return "Layer"
        case .scrollMode:
            return "Scroll Mode"
        case .textAlignment:
            return "Text Horizontal Alignment"
        case .textVerticalAlignment:
            return "Text Vertical Alignment"
        case .fitStyle:
            return "Fit"
        case .animationCurve:
            return "Animation Curve"
        case .lightType:
            return "Light Type"
        case .layerStroke:
            return "Layer Stroke"
        case .textTransform:
            return "Text Transform"
        case .dateAndTimeFormat:
            return "Date and Time Format"
        case .shape:
            return "Shape"
        case .scrollJumpStyle:
            return "Scroll Jump Style"
        case .scrollDecelerationRate:
            return "Scroll Deceleration Rate"
        case .delayStyle:
            return "Delay Style"
        case .shapeCoordinates:
            return "Shape Coordinates"
        case .shapeCommand:
            return "Shape Command"
        case .shapeCommandType:
            return "Shape Command Type"
        case .orientation:
            return "Orientation"
        case .cameraOrientation:
            return "Camera Orientation"
        case .deviceOrientation:
            return "Device Orientation"
        case .vnImageCropOption:
            return "Image Crop & Scale"
        case .textDecoration:
            return "Text Decoration"
        case .textFont:
            return "Text Font"
        case .blendMode:
            return self.rawValue
        case .mapType:
            return "Map Type"
        case .progressIndicatorStyle:
            return "Progress Style"
        case .mobileHapticStyle:
            return "Haptic Style"
        case .strokeLineCap, .strokeLineJoin, .contentMode, .spacing, .padding, .sizingScenario, .pinToId:
            return self.rawValue
        }
    }
}

extension UserVisibleType {
    init(_ value: PortValue) {
        self = portValueToNodeType(value)
    }
}

extension PortValue {
    var toNodeType: UserVisibleType {
        portValueToNodeType(self)
    }
}

// Only used in `changeInputType`
func portValueToNodeType(_ value: PortValue) -> UserVisibleType {
    switch value {
    case .string:
        return .string
    case .bool:
        return .bool
    case .int:
        return .int
    case .color:
        return .color
    case .number:
        return .number
    case .layerDimension:
        return .layerDimension
    case .size:
        return .size
    case .position:
        return .position
    case .point3D:
        return .point3D
    case .point4D:
        return .point4D
    case .transform:
        return .transform
    case .plane:
        return .plane
    case .pulse:
        return .pulse
    case .asyncMedia:
        return .media
    case .json:
        return .json
    case .networkRequestType:
        return .networkRequestType
    case .none:
        return .none
    case .anchoring:
        return .anchoring
    case .cameraDirection:
        return .cameraDirection
    case .assignedLayer:
        return .interactionId
    case .scrollMode:
        return .scrollMode
    case .textAlignment:
        return .textAlignment
    case .textVerticalAlignment:
        return .textVerticalAlignment
    case .fitStyle:
        return .fitStyle
    case .animationCurve:
        return .animationCurve
    case .lightType:
        return .lightType
    case .layerStroke:
        return .layerStroke
    case .textTransform:
        return .textTransform
    case .dateAndTimeFormat:
        return .dateAndTimeFormat
    case .shape:
        return .shape
    case .scrollJumpStyle:
        return .scrollJumpStyle
    case .scrollDecelerationRate:
        return .scrollDecelerationRate
    case .comparable(let type):
        switch type {
        case .none:
            return .none
        case .number:
            return .number
        case .string:
            return .string
        case .bool:
            return .bool
        }
    case .delayStyle:
        return .delayStyle
    case .shapeCoordinates:
        return .shapeCoordinates
    case .shapeCommand:
        return .shapeCommand
    case .shapeCommandType:
        return .shapeCommandType
    case .orientation:
        return .orientation
    case .cameraOrientation:
        return .cameraOrientation
    case .deviceOrientation:
        return .deviceOrientation
    case .vnImageCropOption:
        return .vnImageCropOption
    case .textDecoration:
        return .textDecoration
    case .textFont:
        return .textFont
    case .blendMode:
        return .blendMode
    case .mapType:
        return .mapType
    case .progressIndicatorStyle:
        return .progressIndicatorStyle
    case .mobileHapticStyle:
        return .mobileHapticStyle
    case .strokeLineCap:
        return .strokeLineCap
    case .strokeLineJoin:
        return .strokeLineJoin
    case .contentMode:
        return .contentMode
    case .spacing:
        return .spacing
    case .padding:
        return .padding
    case .sizingScenario:
        return .sizingScenario
    case .pinTo:
        return .pinToId
    }

}

extension UserVisibleType {

    // When converting a node type (i.e. UVT) to a port value,
    // we don't care about the actual content of the associated value for that port value.
    // TODO: instead of using `defaultPortValue`, just pass in the UVT directly
    var toPortValue: PortValue {
        self.defaultPortValue
    }

    // given a user-visible node type, get its corresponding PortValue
    var defaultPortValue: PortValue {
        //    log("nodeTypeToPortValue: nodeType: \(nodeType)")
        switch self {
        case .string:
            return stringDefault
        case .number:
            return numberDefaultFalse
        case .layerDimension:
            return layerDimensionDefaultFalse
        case .int:
            return intDefaultFalse
        case .bool:
            return boolDefaultFalse
        case .color:
            return colorDefaultFalse
        // NOT CORRECT FOR size, position, point3D etc.
        // because eg position becomes
        case .size:
            return defaultSizeFalse
        case .position:
            return defaultPositionFalse
        case .point3D:
            return point3DDefaultFalse
        case .point4D:
            return point4DDefaultFalse
            //TODO: Change
        case .transform:
            return defaultTransformAnchor
        case .pulse:
            return pulseDefaultFalse
        case .media:
            return mediaDefault
        case .json:
            return jsonDefault
        case .none:
            return .none
        case .anchoring:
            return .anchoring(.defaultAnchoring)
        case .cameraDirection:
            return cameraDirectionDefault
        case .interactionId:
            return interactionIdDefault
        case .scrollMode:
            return scrollModeDefault
        case .textAlignment:
            return defaultTextAlignment
        case .textVerticalAlignment:
            return defaultTextVerticalAlignment
        case .fitStyle:
            return .fitStyle(defaultMediaFitStyle)
        case .animationCurve:
            return .animationCurve(defaultAnimationCurve)
        case .lightType:
            return .lightType(defaultLightType)
        case .layerStroke:
            return .layerStroke(.defaultStroke)
        case .textTransform:
            return .textTransform(.defaultTransform)
        case .dateAndTimeFormat:
            return .dateAndTimeFormat(.defaultFormat)
        case .shape:
            return .shape(.triangleShapePatchNodeDefault)
        case .scrollJumpStyle:
            return .scrollJumpStyle(.scrollJumpStyleDefault)
        case .scrollDecelerationRate:
            return .scrollDecelerationRate(.scrollDecelerationRateDefault)
        case .plane:
            return .plane(.any)
        case .networkRequestType:
            return .networkRequestType(.get)
        case .delayStyle:
            return .delayStyle(.always)
        case .shapeCoordinates:
            return .shapeCoordinates(.relative)
        case .shapeCommand:
            return .shapeCommand(.defaultFalseShapeCommand)
        case .shapeCommandType:
            return .shapeCommandType(.defaultFalseShapeCommandType)
        case .orientation:
            return .orientation(.defaultOrientation)
        case .cameraOrientation:
            return .cameraOrientation(.landscapeRight)
        case .deviceOrientation:
            return .deviceOrientation(.defaultDeviceOrientation)
        case .vnImageCropOption:
            return .vnImageCropOption(.centerCrop).defaultFalseValue
        case .textDecoration:
            return .textDecoration(.defaultLayerTextDecoration)
        case .textFont:
            return .textFont(.defaultStitchFont)
        case .blendMode:
            return .blendMode(.defaultBlendMode)
        case .mapType:
            return .mapType(.defaultMapType)
        case .mobileHapticStyle:
            return .mobileHapticStyle(.defaultMobileHapticStyle)
        case .progressIndicatorStyle:
            return .progressIndicatorStyle(.circular)
        case .strokeLineCap:
            return .strokeLineCap(.defaultStrokeLineCap)
        case .strokeLineJoin:
            return .strokeLineJoin(.defaultStrokeLineJoin)
        case .contentMode:
            return .contentMode(.defaultContentMode)
        case .spacing:
            return .spacing(.defaultStitchSpacing)
        case .padding:
            return .padding(.defaultPadding)
        case .sizingScenario:
            return .sizingScenario(.defaultSizingScenario)
        case .pinToId:
            return .pinTo(.defaultPinToId)
        }
    }

}
