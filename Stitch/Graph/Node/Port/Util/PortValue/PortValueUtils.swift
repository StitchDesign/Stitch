//
//  PortValue.swift
//  prototype
//
//  Created by cjc on 2/1/21.
//

import Foundation
import StitchSchemaKit
import CoreData
import SwiftUI
import SwiftyJSON
import NonEmpty
import SceneKit
import OrderedCollections
import RealityKit
import ARKit

extension PortValue {
    var getString: StitchStringValue? {
        switch self {
        case .string(let x): return x
        default: return nil
        }
    }

    var getColor: Color? {
        switch self {
        case .color(let x): return x
        default: return nil
        }
    }

    var getInt: Int? {
        switch self {
        case .int(let x): return x
        default: return nil
        }
    }

    var getNumber: Double? {
        switch self {
        case .number(let x): return x
        default: return nil
        }
    }

    var getLayerDimension: LayerDimension? {
        switch self {
        case .layerDimension(let x): 
            return x
        case .number(let x):
            return .number(x)
        default: return nil
        }
    }

    var getBool: Bool? {
        switch self {
        case .bool(let x): return x
        default: return nil
        }
    }

    var getSize: LayerSize? {
        switch self {
        case .size(let x): return x
        default: return nil
        }
    }

    var getPosition: StitchPosition? {
        switch self {
        case .position(let x): return x
        default: return nil
        }
    }

    var getPoint: CGPoint? {
        self.getPosition?.toCGPoint
    }

    var getPoint3D: Point3D? {
        switch self {
        case .point3D(let x): return x
        default: return nil
        }
    }

    var getPoint4D: Point4D? {
        switch self {
        case .point4D(let x): return x
        default: return nil
        }
    }

    var getMatrix: StitchMatrix? {
        switch self {
        case .matrixTransform(let x): return x
        default: return nil
        }
    }

    var getAlignmentType: Plane? {
        switch self {
        case .plane(let x): return x
        default: return nil
        }
    }

    var getPlane: Plane? {
        switch self {
        case .plane(let x): return x
        default: return nil
        }
    }

    var getPulse: TimeInterval? {
        switch self {
        case .pulse(let x): return x
        default: return nil
        }
    }

    var asyncMedia: GraphMediaValue? {
        switch self {
        case.asyncMedia(let media):
            guard let media = media else {
                return nil
            }
            return GraphMediaValue(from: media)
        default:
            return nil
        }
    }
    
    /// Tech debt, only used for file import.
    var _asyncMedia: AsyncMediaValue? {
        switch self {
        case.asyncMedia(let media):
            return media
        default:
            return nil
        }
    }

    var getJSON: JSON? {
        self.getStitchJSON?.value
    }

    var getStitchJSON: StitchJSON? {
        switch self {
        case .json(let x): return x
        default: return nil
        }
    }

    var getNetworkRequestType: NetworkRequestType? {
        switch self {
        case .networkRequestType(let x): return x
        default: return nil
        }
    }

    var getAnchoring: Anchoring? {
        switch self {
        case .anchoring(let x): return x
        default: return nil
        }
    }

    // ... better to use the parsers here?
    var asCGFloat: CGFloat {
        switch self {
        case .number(let x): return CGFloat(x)
        default: return CGFloat.zero
        }
    }

    var getCameraDirection: CameraDirection? {
        switch self {
        case .cameraDirection(let x): return x
        default: return nil
        }
    }

    var getInteractionId: LayerNodeId? {
        switch self {
        case .assignedLayer(let x): return x
        default: return nil
        }
    }

    var getScrollMode: ScrollMode? {
        switch self {
        case .scrollMode(let x): return x
        default: return nil
        }
    }

    var getLayerTextAlignment: LayerTextAlignment? {
        switch self {
        case .textAlignment(let x): return x
        default: return nil
        }
    }

    var getLayerTextVerticalAlignment: LayerTextVerticalAlignment? {
        switch self {
        case .textVerticalAlignment(let x): return x
        default: return nil
        }
    }

    var getFitStyle: VisualMediaFitStyle? {
        switch self {
        case .fitStyle(let x): return x
        default: return nil
        }
    }

    var getAnimationCurve: ClassicAnimationCurve? {
        switch self {
        case .animationCurve(let x): return x
        default: return nil
        }
    }

    var getLightType: LightType? {
        switch self {
        case .lightType(let x): return x
        default: return nil
        }
    }

    var getLayerStroke: LayerStroke? {
        switch self {
        case .layerStroke(let x): return x
        default: return nil
        }
    }

    var getImportedMediaKey: MediaKey? {
        switch self {
        case .asyncMedia(let media):
            return media?.mediaKey
        default:
            return nil
        }
    }

    var getTextTransform: TextTransform? {
        switch self {
        case .textTransform(let x): return x
        default: return nil
        }
    }

    var getDateAndTimeFormat: DateAndTimeFormat? {
        switch self {
        case .dateAndTimeFormat(let x): return x
        default: return nil
        }
    }

    var getShape: CustomShape? {
        switch self {
        case .shape(let x): return x
        default: return nil
        }
    }

    var getScrollJumpStyle: ScrollJumpStyle? {
        switch self {
        case .scrollJumpStyle(let x): return x
        default: return nil
        }
    }

    var getScrollDecelerationRate: ScrollDecelerationRate? {
        switch self {
        case .scrollDecelerationRate(let x): return x
        default: return nil
        }
    }

    var comparableValue: PortValueComparable? {
        switch self {
        case .comparable(let x):
            return x
        case .number(let x):
            return .number(x)
        case .string(let x):
            return .string(x)
        case .bool(let x):
            return .bool(x)
        case .layerDimension(let x):
            return .number(x.asNumber)
        default:
            return nil
        }
    }

    var delayStyle: DelayStyle? {
        switch self {
        case .delayStyle(let delayStyle):
            return delayStyle
        default:
            return nil
        }
    }

    var getShapeCoordinates: ShapeCoordinates? {
        switch self {
        case .shapeCoordinates(let x):
            return x
        default:
            return nil
        }
    }

    var shapeCommandType: ShapeCommandType? {
        switch self {
        case .shapeCommandType(let shapeCommandType):
            return shapeCommandType
        default:
            return nil
        }
    }

    var shapeCommand: ShapeCommand? {
        switch self {
        case .shapeCommand(let shapeCommand):
            return shapeCommand
        default:
            return nil
        }
    }

    var getOrientation: StitchOrientation? {
        switch self {
        case .orientation(let x):
            return x
        default:
            return nil
        }
    }

    var getCameraOrientation: StitchCameraOrientation? {
        switch self {
        case .cameraOrientation(let x):
            return x
        default:
            return nil
        }
    }

    var getDeviceOrientation: StitchDeviceOrientation? {
        switch self {
        case .deviceOrientation(let x):
            return x
        default:
            return nil
        }
    }

    var vnImageCropOption: VNImageCropAndScaleOption? {
        switch self {
        case .vnImageCropOption(let option):
            return option
        default:
            return nil
        }
    }

    var getTextDecoration: LayerTextDecoration? {
        switch self {
        case .textDecoration(let x):
            return x
        default:
            return nil
        }
    }

    var getTextFont: StitchFont? {
        switch self {
        case .textFont(let x):
            return x
        default:
            return nil
        }
    }

    var getBlendMode: StitchBlendMode? {
        switch self {
        case .blendMode(let x):
            return x
        default:
            return nil
        }
    }
    
    var getMapType: StitchMapType? {
        switch self {
        case .mapType(let x):
            return x
        default:
            return nil
        }
    }
    
    var getProgressIndicatorStyle: ProgressIndicatorStyle? {
        switch self {
        case .progressIndicatorStyle(let x):
            return x
        default:
            return nil
        }
    }
    
    var getMobileHapticStyle: MobileHapticStyle? {
        switch self {
        case .mobileHapticStyle(let x):
            return x
        default:
            return nil
        }
    }
    
    var getStrokeLineCap: StrokeLineCap? {
        switch self {
        case .strokeLineCap(let x):
            return x
        default:
            return nil
        }
    }
    
    var getStrokeLineJoin: StrokeLineJoin? {
        switch self {
        case .strokeLineJoin(let x):
            return x
        default:
            return nil
        }
    }
 
    init(fromPortDataValue portDataValue: PortDataValue) {
        switch portDataValue {
        case .string(let value):
            self = .string(value)
        case .bool(let value):
            self = .bool(value)
        case .int(let value):
            self = .int(value)
        case .number(let value):
            self = .number(value)
        case .layerDimension(let value):
            self = .layerDimension(value)
        case .matrixTransform(let value):
            self = .matrixTransform(value)
        case .plane(let value):
            self = .plane(value)
        case .networkRequestType(let value):
            self = .networkRequestType(value)
        case .color(let value):
            self = .color(value)
        case .size(let value):
            self = .size(value)
        case .position(let value):
            self = .position(value)
        case .point3D(let value):
            self = .point3D(value)
        case .point4D(let value):
            self = .point4D(value)
        case .pulse(let value):
            self = .pulse(value)
        case .asyncMedia(let value):
            self = .asyncMedia(value)
        case .json(let value):
            self = .json(value)
        case .none:
            self = .none
        case .anchoring(let value):
            self = .anchoring(value)
        case .cameraDirection(let value):
            self = .cameraDirection(value)
        case .assignedLayer(let value):
            self = .assignedLayer(value)
        case .scrollMode(let value):
            self = .scrollMode(value)
        case .textAlignment(let value):
            self = .textAlignment(value)
        case .textVerticalAlignment(let value):
            self = .textVerticalAlignment(value)
        case .fitStyle(let value):
            self = .fitStyle(value)
        case .animationCurve(let value):
            self = .animationCurve(value)
        case .lightType(let value):
            self = .lightType(value)
        case .layerStroke(let value):
            self = .layerStroke(value)
        case .textTransform(let value):
            self = .textTransform(value)
        case .dateAndTimeFormat(let value):
            self = .dateAndTimeFormat(value)
        case .shape(let value):
            self = .shape(value)
        case .scrollJumpStyle(let value):
            self = .scrollJumpStyle(value)
        case .scrollDecelerationRate(let value):
            self = .scrollDecelerationRate(value)
        case .comparable(let value):
            self = .comparable(value)
        case .delayStyle(let value):
            self = .delayStyle(value)
        case .shapeCoordinates(let value):
            self = .shapeCoordinates(value)
        case .shapeCommandType(let value):
            self = .shapeCommandType(value)
        case .shapeCommand(let value):
            self = .shapeCommand(value)
        case .orientation(let value):
            self = .orientation(value)
        case .cameraOrientation(let value):
            self = .cameraOrientation(value)
        case .deviceOrientation(let value):
            self = .deviceOrientation(value)
        case .vnImageCropOption(let value):
            self = .vnImageCropOption(value)
        case .textDecoration(value: let value):
            self = .textDecoration(value)
        case .textFont(value: let value):
            self = .textFont(value)
        case .blendMode(value: let value):
            self = .blendMode(value)
        case .mapType(value: let value):
            self = .mapType(value)
        case .progressIndicatorStyle(value: let value):
            self = .progressIndicatorStyle(value)
        case .mobileHapticStyle(value: let value):
            self = .mobileHapticStyle(value)
        case .strokeLineCap(value: let value):
            self = .strokeLineCap(value)
        case .strokeLineJoin(value: let value):
            self = .strokeLineJoin(value)
        }
    }
}

enum PortDataValue: Equatable, Codable {
    case string(value: StitchStringValue)
    case bool(value: Bool)
    case int(value: Int) // e.g  nodeId or index?
    case number(value: Double) // e.g. CGFloat, part of CGSize, etc.
    case layerDimension(value: LayerDimension)
    case matrixTransform(value: StitchMatrix)
    case plane(value: Plane)
    case networkRequestType(value: NetworkRequestType)
    case color(value: Color)
    case size(value: LayerSize)
    case position(value: StitchPosition) // TODO: use `CGPoint` instead of `CGSize`
    case point3D(value: Point3D)
    case point4D(value: Point4D)
    case pulse(value: TimeInterval) // TimeInterval = last time this input/output pulsed
    case asyncMedia(value: AsyncMediaValue?)
    case json(value: StitchJSON)
    case none // how to avoid this?
    case anchoring(value: Anchoring)
    case cameraDirection(value: CameraDirection)
    case assignedLayer(value: LayerNodeId?)
    case scrollMode(value: ScrollMode)
    case textAlignment(value: LayerTextAlignment)
    case textVerticalAlignment(value: LayerTextVerticalAlignment)
    case fitStyle(value: VisualMediaFitStyle)
    case animationCurve(value: ClassicAnimationCurve)
    case lightType(value: LightType)
    case layerStroke(value: LayerStroke)
    case textTransform(value: TextTransform)
    case dateAndTimeFormat(value: DateAndTimeFormat)
    case shape(value: CustomShape?)
    case scrollJumpStyle(value: ScrollJumpStyle)
    case scrollDecelerationRate(value: ScrollDecelerationRate)
    case comparable(value: PortValueComparable?)
    case delayStyle(value: DelayStyle)
    case shapeCoordinates(value: ShapeCoordinates)
    case shapeCommandType(value: ShapeCommandType) // not exposed to user
    case shapeCommand(value: ShapeCommand)
    case orientation(value: StitchOrientation)
    case cameraOrientation(value: StitchCameraOrientation)
    case deviceOrientation(value: StitchDeviceOrientation)
    case vnImageCropOption(value: VNImageCropAndScaleOption)
    case textDecoration(value: LayerTextDecoration)
    case textFont(value: StitchFont)
    case blendMode(value: StitchBlendMode)
    case mapType(value: StitchMapType)
    case progressIndicatorStyle(value: ProgressIndicatorStyle)
    case mobileHapticStyle(value: MobileHapticStyle)
    case strokeLineCap(value: StrokeLineCap)
    case strokeLineJoin(value: StrokeLineJoin)
}

extension PortValue {
    func toPortDataValue() -> PortDataValue {
        switch self {
        case .string(let value):
            return .string(value: value)
        case .bool(let value):
            return .bool(value: value)
        case .int(let value):
            return .int(value: value)
        case .number(let value):
            return .number(value: value)
        case .layerDimension(let value):
            return .layerDimension(value: value)
        case .matrixTransform(let value):
            return .matrixTransform(value: value)
        case .plane(let value):
            return .plane(value: value)
        case .networkRequestType(let value):
            return .networkRequestType(value: value)
        case .color(let value):
            return .color(value: value)
        case .size(let value):
            return .size(value: value)
        case .position(let value):
            return .position(value: value)
        case .point3D(let value):
            return .point3D(value: value)
        case .point4D(let value):
            return .point4D(value: value)
        case .pulse(let value):
            return .pulse(value: value)
        case .asyncMedia(let value):
            return .asyncMedia(value: value)
        case .json(let value):
            return .json(value: value)
        case .none:
            return .none
        case .anchoring(let value):
            return .anchoring(value: value)
        case .cameraDirection(let value):
            return .cameraDirection(value: value)
        case .assignedLayer(let value):
            return .assignedLayer(value: value)
        case .scrollMode(let value):
            return .scrollMode(value: value)
        case .textAlignment(let value):
            return .textAlignment(value: value)
        case .textVerticalAlignment(let value):
            return .textVerticalAlignment(value: value)
        case .fitStyle(let value):
            return .fitStyle(value: value)
        case .animationCurve(let value):
            return .animationCurve(value: value)
        case .lightType(let value):
            return .lightType(value: value)
        case .layerStroke(let value):
            return .layerStroke(value: value)
        case .textTransform(let value):
            return .textTransform(value: value)
        case .dateAndTimeFormat(let value):
            return .dateAndTimeFormat(value: value)
        case .shape(let value):
            return .shape(value: value)
        case .scrollJumpStyle(let value):
            return .scrollJumpStyle(value: value)
        case .scrollDecelerationRate(let value):
            return .scrollDecelerationRate(value: value)
        case .comparable(let value):
            return .comparable(value: value)
        case .delayStyle(let value):
            return .delayStyle(value: value)
        case .shapeCoordinates(let value):
            return .shapeCoordinates(value: value)
        case .shapeCommandType(let value):
            return .shapeCommandType(value: value)
        case .shapeCommand(let value):
            return .shapeCommand(value: value)
        case .orientation(let value):
            return .orientation(value: value)
        case .cameraOrientation(let value):
            return .cameraOrientation(value: value)
        case .deviceOrientation(let value):
            return .deviceOrientation(value: value)
        case .vnImageCropOption(let value):
            return .vnImageCropOption(value: value)
        case .textDecoration(let value):
            return .textDecoration(value: value)
        case .textFont(let value):
            return .textFont(value: value)
        case .blendMode(let value):
            return .blendMode(value: value)
        case .mapType(let value):
            return .mapType(value: value)
        case .progressIndicatorStyle(let value):
            return .progressIndicatorStyle(value: value)
        case .mobileHapticStyle(let value):
            return .mobileHapticStyle(value: value)
        case .strokeLineCap(let value):
            return .strokeLineCap(value: value)
        case .strokeLineJoin(let value):
            return .strokeLineJoin(value: value)
        }
    }
}
