//
//  SingleDropdownKind.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit
import Vision

enum SingleDropdownKind {
    case textAlignment, textVerticalAlignment, textDecoration, blendMode, fitStyle, animationCurve, cameraDirection, cameraOrientation, deviceOrientation, plane, scrollMode, lightType, networkRequestType, layerStroke, textTransform, dateAndTimeFormat, scrollJumpStyle, scrollDecelerationRate, delayStyle, shapeCoordinates, shapeCommandType, vnImageCropAndScale, mapType, progressIndicatorStyle, mobileHapticStyle, strokeLineCap, strokeLineJoin, contentMode, sizingScenario, materialThickness, deviceAppearance, keyboardType
}

extension SingleDropdownKind {
    var choices: PortValues {
        switch self {
        case .textAlignment:
            return LayerTextAlignment.choices
        case .textVerticalAlignment:
            return LayerTextVerticalAlignment.choices
        case .textDecoration:
            return LayerTextDecoration.choices
        case .fitStyle:
            return VisualMediaFitStyle.choices
        case .animationCurve:
            return ClassicAnimationCurve.choices
        case .cameraDirection:
            return CameraDirection.choices
        case .plane:
            return Plane.choices
        case .scrollMode:
            return ScrollMode.choices
        case .lightType:
            return LightType.choices
        case .networkRequestType:
            return NetworkRequestType.choices
        case .layerStroke:
            return LayerStroke.choices
        case .textTransform:
            return TextTransform.choices
        case .dateAndTimeFormat:
            return DateAndTimeFormat.choices
        case .scrollJumpStyle:
            return ScrollJumpStyle.choices
        case .scrollDecelerationRate:
            return ScrollDecelerationRate.choices
        case .delayStyle:
            return DelayStyle.choices
        case .shapeCoordinates:
            return ShapeCoordinates.choices
        case .shapeCommandType:
            return ShapeCommandType.choices
        case .cameraOrientation:
            return StitchCameraOrientation.choices
        case .deviceOrientation:
            return StitchDeviceOrientation.choices
        case .vnImageCropAndScale:
            return VNImageCropAndScaleOption.choices
        case .blendMode:
            return StitchBlendMode.choices
        case .mapType:
            return StitchMapType.choices
        case .progressIndicatorStyle:
            return ProgressIndicatorStyle.choices
        case .mobileHapticStyle:
            return MobileHapticStyle.choices
        case .strokeLineCap:
            return StrokeLineCap.choices
        case .strokeLineJoin:
            return StrokeLineJoin.choices
        case .contentMode:
            return StitchContentMode.choices
        case .sizingScenario:
            return SizingScenario.choices
        case .materialThickness:
            return MaterialThickness.choices
        case .deviceAppearance:
            return DeviceAppearance.choices
        case .keyboardType:
            return KeyboardType.choices
        }
    }
}

extension SizingScenario: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.sizingScenario
    }
}
