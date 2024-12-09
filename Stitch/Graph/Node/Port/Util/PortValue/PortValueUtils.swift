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

    var getPosition: CGPoint? {
        switch self {
        case .position(let x): return x
        default: return nil
        }
    }

    var getPoint: CGPoint? {
        self.getPosition
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
    
    var getPadding: StitchPadding? {
        switch self {
        case .padding(let x): return x
        default: return nil
        }
    }

    var getTransform: StitchTransform? {
        switch self {
        case .transform(let x): return x
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
 
    var getContentMode: StitchContentMode? {
        switch self {
        case .contentMode(let x):
            return x
        default:
            return nil
        }
    }    
    
    var getStitchSpacing: StitchSpacing? {
        switch self {
        case .spacing(let x):
            return x
        default:
            return nil
        }
    }
    
    var getSizingScenario: SizingScenario? {
        switch self {
        case .sizingScenario(let x):
            return x
        default:
            return nil
        }
    }
    
    var getPinToId: PinToId? {
        switch self {
        case .pinTo(let x):
            return x
        default:
            return nil
        }
    }
    
    var getMaterialThickness: MaterialThickness? {
        switch self {
        case .materialThickness(let x):
            return x
        default:
            return nil
        }
    }
    
    var getDeviceAppearance: DeviceAppearance? {
        switch self {
        case .deviceAppearance(let x):
            return x
        default:
            return nil
        }
    }
    
    var anchorEntity: UUID? {
        switch self {
        case .anchorEntity(let nodeId):
            return nodeId
        default:
            return nil
        }
    }
}

extension SizingScenario {
    static let defaultSizingScenario: Self = .auto
    
    var display: String {
        self.rawValue
    }
}
