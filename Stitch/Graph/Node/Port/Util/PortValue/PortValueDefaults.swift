//
//  PortValueDefaults.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/6/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SceneKit
import RealityKit
import SwiftyJSON

/* ----------------------------------------------------------------
 PortValues: default values
 ---------------------------------------------------------------- */

let stringDefault: PortValue = .string(.init(.empty))

let boolDefaultTrue: PortValue = .bool(true)
let boolDefaultFalse: PortValue = .bool(false)

let intDefaultTrue: PortValue = .int(1)
let intDefaultFalse: PortValue = .int(0)

let defaultNumber: PortValue = .number(0)
let numberDefaultTrue: PortValue = .number(1)
let numberDefaultFalse: PortValue = .number(0)

extension Double {
    static let numberDefaultTrue = 1.0
    static let numberDefaultFalse = 0.0
}

let layerDimensionDefaultTrue: PortValue = .layerDimension(LayerDimension.number(1))
let layerDimensionDefaultFalse: PortValue = .layerDimension(LayerDimension.number(.zero))

let colorDefaultTrue = PortValue.color(trueColor)
let colorDefaultFalse = PortValue.color(falseColor)

let defaultOpacityValue: PortValue = .number(1)
let defaultLightPositionValue: PortValue = .position(CGPoint(x: 0, y: 10))

let pulseDefaultFalse = PortValue.pulse(.zero)

let defaultSizeFalse: PortValue = .size(CGSize(width: 0, height: 0).toLayerSize)

extension LayerSize {
    static let defaultTrue: Self = .init(width: 1, height: 1)
    static let defaultFalse: Self = .init(.zero)
}

extension StitchPosition {
    static let defaultTrue: Self = .init(x: 1, y: 1)
    static let defaultFalse: Self = .zero
}

let defaultPositionTrue: PortValue = .position(.init(x: 1, y: 1))
let defaultPositionFalse: PortValue = .position(.zero)

extension Point3D {
    static let defaultTrue: Self = Point3D.nonZero
    static let defaultFalse: Self = Point3D.zero
    
    static func fromSingleNumber(_ n: Double) -> Self {
        .init(x: n, y: n, z: n)
    }
}

let point3DDefaultTrue: PortValue = .point3D(Point3D.nonZero)
let point3DDefaultFalse: PortValue = .point3D(Point3D.zero)

extension Point4D {
    static let defaultTrue: Self = Point4D.nonZero
    static let defaultFalse: Self = Point4D.zero
    
    static func fromSingleNumber(_ n: Double) -> Self {
        .init(x: n, y: n, z: n, w: n)
    }
}

let point4DDefaultTrue: PortValue = .point4D(Point4D.nonZero)
let point4DDefaultFalse: PortValue = .point4D(Point4D.zero)

let defaultTransformEntity: PortValue = .transform(DEFAULT_STITCH_TRANSFORM)
let defaultTransformAnchor: PortValue = .transform(DEFAULT_STITCH_TRANSFORM)

let defaultTransform: PortValue = .transform(DEFAULT_STITCH_TRANSFORM)


let planeDefault: PortValue = .plane(.any)

let mediaDefault: PortValue = .asyncMedia(nil)

// TODO: Why is this necessary? Somehow in our JSON Popover logic, we were turning "{}" into "{\n\n}";
// by using "{\n\n}" for our JSON PortValue type
let jsonDefaultRaw = "{\n\n}"
let jsonDefault: PortValue = .json(JSON(parseJSON: jsonDefaultRaw).toStitchJSON)
// let jsonDefault: PortValue = .json("{}")

let sampleJson: String = "{\"key1\": \"love\", \"key2\": 5}"

let networkRequestTypeDefault: PortValue = .networkRequestType(.get)

let cameraDirectionDefault: PortValue = .cameraDirection(.front)

func defaultToyRobot3DModel(nodeId: NodeId, loopIndex: Int) -> AsyncMediaValue {
    AsyncMediaValue(mediaKey: default3DModelToyRobotAsset.mediaKey)
}

let default3DModelLayerSize = CGSize(width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width, height: 200).toLayerSize

let defaultRealityViewLayerSize = CGSize(width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width, height: 200).toLayerSize

let interactionIdDefault: PortValue = .assignedLayer(nil)

let scrollModeDefault: PortValue = .scrollMode(.scrollModeDefault)

let vnImageCropDefaultValue: PortValue = .vnImageCropOption(.scaleFill)

// Default false values
extension PortValue {

    var defaultFalseValue: PortValue {
        switch self {
        case .string:
            return stringDefault
        case .bool:
            return boolDefaultFalse
        case .int:
            return intDefaultFalse
        case .number:
            return numberDefaultFalse
        case .layerDimension:
            return layerDimensionDefaultFalse
        case .color:
            return colorDefaultFalse
        case .size:
            return defaultSizeFalse
        case .position:
            return defaultPositionFalse
        case .point3D:
            return point3DDefaultFalse
        case .point4D:
            return point4DDefaultFalse
        case .transform:
            return defaultTransformAnchor
        case .plane:
            return planeDefault
        case .pulse:
            return pulseDefaultFalse
        case .asyncMedia:
            return mediaDefault
        case .json:
            return jsonDefault
        case .networkRequestType:
            return networkRequestTypeDefault
        case .none:
            return .none
        case .anchoring:
            return .anchoring(.defaultAnchoring)
        case .cameraDirection:
            return cameraDirectionDefault
        case .assignedLayer:
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
            return .shape(nil)
        case .scrollJumpStyle:
            return .scrollJumpStyle(.scrollJumpStyleDefault)
        case .scrollDecelerationRate:
            return .scrollDecelerationRate(.scrollDecelerationRateDefault)
        case .comparable:
            return numberDefaultFalse
        case .delayStyle:
            return .delayStyle(.always)
        case .shapeCoordinates:
            return .shapeCoordinates(.relative)
        case .shapeCommandType:
            return .shapeCommandType(.defaultFalseShapeCommandType)
        case .shapeCommand(let x):
            return .shapeCommand(x.defaultFalseValue)
        case .orientation:
            return .orientation(.defaultOrientation)
        case .cameraOrientation:
            return .cameraOrientation(.portrait)
        case .deviceOrientation:
            return .deviceOrientation(.defaultDeviceOrientation)
        case .vnImageCropOption:
            return vnImageCropDefaultValue
        case .textDecoration:
            return .textDecoration(.defaultLayerTextDecoration)
        case .textFont:
            return .textFont(.defaultStitchFont)
        case .blendMode:
            return .blendMode(.defaultBlendMode)
        case .mapType:
            return .mapType(.standard)
        case .progressIndicatorStyle:
            return .progressIndicatorStyle(.circular)
        case .mobileHapticStyle:
            return .mobileHapticStyle(.heavy)
        case .strokeLineCap:
            return .strokeLineCap(.defaultStrokeLineCap)
        case .strokeLineJoin:
            return .strokeLineJoin(.defaultStrokeLineJoin)
        case .contentMode:
            return .contentMode(.defaultContentMode)
        case .spacing:
            return .spacing(.defaultStitchSpacing)
        case .padding:
            return .padding(.zero)
        case .sizingScenario:
            return .sizingScenario(.defaultSizingScenario)
        case .pinTo:
            return .pinTo(.defaultPinToId)
        case .materialThickness:
            return .materialThickness(.defaultMaterialThickness)
        case .deviceAppearance:
            return .deviceAppearance(.defaultDeviceAppearance)
        case .anchorEntity:
            return .anchorEntity(nil)
        }
    }
}
