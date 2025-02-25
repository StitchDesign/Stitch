//
//  StitchAITypeCasting.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/7/25.
//

import SwiftUI
import StitchSchemaKit
import Vision

extension PortValue {
    var anyCodable: any Codable {
        switch self {
        case .string(let x):
            return x.string
        case .bool(let x):
            return x
        case .int(let x):
            return x
        case .number(let x):
            return x
        case .layerDimension(let x):
            return StitchAISizeDimension(value: x)
        case .transform(let x):
            return x
        case .plane(let x):
            return x
        case .networkRequestType(let x):
            return x
        case .color(let x):
            return StitchAIColor(value: x)
        case .size(let size):
            return StitchAISize(width: .init(value: size.width),
                                height: .init(value: size.height))
        case .position(let x):
            return StitchAIPosition(x: x.x, y: x.y)
        case .point3D(let x):
            return x
        case .point4D(let x):
            return x
        case .pulse(let x):
            return x
        case .asyncMedia(let x):
            return x
        case .json(let x):
            return x
        case .anchoring(let x):
            return x
        case .cameraDirection(let x):
            return x
        case .assignedLayer(let x):
            guard let x = x else {
                return "None"
            }
            return StitchAIUUID(value: x.id)
        case .scrollMode(let x):
            return x
        case .textAlignment(let x):
            return x
        case .textVerticalAlignment(let x):
            return x
        case .fitStyle(let x):
            return x
        case .animationCurve(let x):
            return x
        case .lightType(let x):
            return x
        case .layerStroke(let x):
            return x
        case .textTransform(let x):
            return x
        case .dateAndTimeFormat(let x):
            return x
        case .shape(let x):
            return x
        case .scrollJumpStyle(let x):
            return x
        case .scrollDecelerationRate(let x):
            return x
        case .comparable(let x):
            return x
        case .delayStyle(let x):
            return x
        case .shapeCoordinates(let x):
            return x
        case .shapeCommandType(let x):
            return x
        case .shapeCommand(let x):
            return x
        case .orientation(let x):
            return x
        case .cameraOrientation(let x):
            return x
        case .deviceOrientation(let x):
            return x
        case .vnImageCropOption(let x):
            return x
        case .textDecoration(let x):
            return x
        case .textFont(let x):
            return x
        case .blendMode(let x):
            return x
        case .mapType(let x):
            return x
        case .progressIndicatorStyle(let x):
            return x
        case .mobileHapticStyle(let x):
            return x
        case .strokeLineCap(let x):
            return x
        case .strokeLineJoin(let x):
            return x
        case .contentMode(let x):
            return x
        case .spacing(let x):
            return x
        case .padding(let x):
            return x
        case .sizingScenario(let x):
            return x
        case .pinTo(let x):
            return x
        case .deviceAppearance(let x):
            return x
        case .materialThickness(let x):
            return x
        case .anchorEntity(let x):
            return x
        case .none:
            fatalError()
        }
    }
}

extension UserVisibleType {
    /*
     Note: StitchAI treats certain PortValues in an LLM-friendly way, e.g.
     - Color as a hex
     - CGPoint as a dictionary/json-object instead of a tuple
     */
    var portValueTypeForStitchAI: Decodable.Type {
        switch self {
        case .string:
            return String.self
        case .bool:
            return Bool.self
        case .int:
            return Int.self
        case .number:
            return Double.self
        case .layerDimension:
            return StitchAISizeDimension.self
        case .transform:
            return StitchTransform.self
        case .plane:
            return Plane.self
        case .networkRequestType:
            return NetworkRequestType.self
        case .color:
            return StitchAIColor.self
        case .size:
            return StitchAISize.self
        case .position:
            return StitchAIPosition.self
        case .point3D:
            return Point3D.self
        case .point4D:
            return Point4D.self
        case .pulse:
            return TimeInterval.self
        case .media:
            return AsyncMediaValue?.self
        case .json:
            return StitchJSON.self
        case .anchoring:
            return Anchoring.self
        case .cameraDirection:
            return CameraDirection.self
        case .interactionId:
            return StitchAIUUID?.self
        case .scrollMode:
            return ScrollMode.self
        case .textAlignment:
            return LayerTextAlignment.self
        case .textVerticalAlignment:
            return LayerTextVerticalAlignment.self
        case .fitStyle:
            return VisualMediaFitStyle.self
        case .animationCurve:
            return ClassicAnimationCurve.self
        case .lightType:
            return LightType.self
        case .layerStroke:
            return LayerStroke.self
        case .textTransform:
            return TextTransform.self
        case .dateAndTimeFormat:
            return DateAndTimeFormat.self
        case .shape:
            return CustomShape?.self
        case .scrollJumpStyle:
            return ScrollJumpStyle.self
        case .scrollDecelerationRate:
            return ScrollDecelerationRate.self
        case .delayStyle:
            return DelayStyle.self
        case .shapeCoordinates:
            return ShapeCoordinates.self
        case .shapeCommandType:
            return ShapeCommandType.self
        case .shapeCommand:
            return ShapeCommand.self
        case .orientation:
            return StitchOrientation.self
        case .cameraOrientation:
            return StitchCameraOrientation.self
        case .deviceOrientation:
            return StitchDeviceOrientation.self
        case .vnImageCropOption:
            return VNImageCropAndScaleOption.self
        case .textDecoration:
            return LayerTextDecoration.self
        case .textFont:
            return StitchFont.self
        case .blendMode:
            return StitchBlendMode.self
        case .mapType:
            return StitchMapType.self
        case .progressIndicatorStyle:
            return ProgressIndicatorStyle.self
        case .mobileHapticStyle:
            return MobileHapticStyle.self
        case .strokeLineCap:
            return StrokeLineCap.self
        case .strokeLineJoin:
            return StrokeLineJoin.self
        case .contentMode:
            return StitchContentMode.self
        case .spacing:
            return StitchSpacing.self
        case .padding:
            return StitchPadding.self
        case .sizingScenario:
            return SizingScenario.self
        case .deviceAppearance:
            return DeviceAppearance.self
        case .materialThickness:
            return MaterialThickness.self
        case .anchorEntity:
            return UUID?.self
        case .pinToId:
            return PinToId.self
        case .none:
            fatalError()
        }
    }
    
    func coerceToPortValueForStitchAI(from anyValue: Any) throws -> PortValue {
        switch self {
        case .string:
            guard let x = anyValue as? String else {
                throw StitchAIManagerError.typeCasting
            }
            return .string(.init(x))
        case .bool:
            guard let x = anyValue as? Bool else {
                throw StitchAIManagerError.typeCasting
            }
            return .bool(x)
        case .int:
            guard let x = anyValue as? Int else {
                throw StitchAIManagerError.typeCasting
            }
            return .int(x)
        case .number:
            guard let x = anyValue as? Double else {
                throw StitchAIManagerError.typeCasting
            }
            return .number(x)
        case .layerDimension:
            guard let x = anyValue as? StitchAISizeDimension else {
                throw StitchAIManagerError.typeCasting
            }
            return .layerDimension(x.value)
        case .transform:
            guard let x = anyValue as? StitchTransform else {
                throw StitchAIManagerError.typeCasting
            }
            return .transform(x)
        case .plane:
            guard let x = anyValue as? Plane else {
                throw StitchAIManagerError.typeCasting
            }
            return .plane(x)
        case .networkRequestType:
            guard let x = anyValue as? NetworkRequestType else {
                throw StitchAIManagerError.typeCasting
            }
            return .networkRequestType(x)
        case .color:
            guard let stitchAIColor = anyValue as? StitchAIColor else {
                throw StitchAIManagerError.typeCasting
            }
            return .color(stitchAIColor.value)
        case .size:
            guard let aiSize = anyValue as? StitchAISize else {
                throw StitchAIManagerError.typeCasting
            }
            
            let size = LayerSize(width: aiSize.width.value,
                                 height: aiSize.height.value)
            
            return .size(size)
        case .position:
            guard let x = anyValue as? StitchAIPosition else {
                throw StitchAIManagerError.typeCasting
            }
            
            return .position(.init(x: x.x, y: x.y))
        case .point3D:
            guard let x = anyValue as? Point3D else {
                throw StitchAIManagerError.typeCasting
            }
            return .point3D(x)
        case .point4D:
            guard let x = anyValue as? Point4D else {
                throw StitchAIManagerError.typeCasting
            }
            return .point4D(x)
        case .pulse:
            guard let x = anyValue as? TimeInterval else {
                throw StitchAIManagerError.typeCasting
            }
            return .pulse(x)
        case .media:
            guard let x = anyValue as? AsyncMediaValue? else {
                throw StitchAIManagerError.typeCasting
            }
            return .asyncMedia(x)
        case .json:
            guard let x = anyValue as? StitchJSON else {
                throw StitchAIManagerError.typeCasting
            }
            return .json(x)
        case .anchoring:
            guard let x = anyValue as? Anchoring else {
                throw StitchAIManagerError.typeCasting
            }
            return .anchoring(x)
        case .cameraDirection:
            guard let x = anyValue as? CameraDirection else {
                throw StitchAIManagerError.typeCasting
            }
            return .cameraDirection(x)
        case .interactionId:
            guard let x = anyValue as? StitchAIUUID? else {
                if let xString = anyValue as? String,
                   // TODO: how did "None" get wrapped with extra quotes?
                   (xString == "None") {
//                   (xString == "None" || xString == "\"None\"") {
                    return .assignedLayer(nil)
                }
                
                throw StitchAIManagerError.typeCasting
            }
            
            if let x = x {
                return .assignedLayer(.init(x.value))
            }
            
            return .assignedLayer(nil)
            
        case .scrollMode:
            guard let x = anyValue as? ScrollMode else {
                throw StitchAIManagerError.typeCasting
            }
            return .scrollMode(x)
        case .textAlignment:
            guard let x = anyValue as? LayerTextAlignment else {
                throw StitchAIManagerError.typeCasting
            }
            return .textAlignment(x)
        case .textVerticalAlignment:
            guard let x = anyValue as? LayerTextVerticalAlignment else {
                throw StitchAIManagerError.typeCasting
            }
            return .textVerticalAlignment(x)
        case .fitStyle:
            guard let x = anyValue as? VisualMediaFitStyle else {
                throw StitchAIManagerError.typeCasting
            }
            return .fitStyle(x)
        case .animationCurve:
            guard let x = anyValue as? ClassicAnimationCurve else {
                throw StitchAIManagerError.typeCasting
            }
            return .animationCurve(x)
        case .lightType:
            guard let x = anyValue as? LightType else {
                throw StitchAIManagerError.typeCasting
            }
            return .lightType(x)
        case .layerStroke:
            guard let x = anyValue as? LayerStroke else {
                throw StitchAIManagerError.typeCasting
            }
            return .layerStroke(x)
        case .textTransform:
            guard let x = anyValue as? TextTransform else {
                throw StitchAIManagerError.typeCasting
            }
            return .textTransform(x)
        case .dateAndTimeFormat:
            guard let x = anyValue as? DateAndTimeFormat else {
                throw StitchAIManagerError.typeCasting
            }
            return .dateAndTimeFormat(x)
        case .shape:
            guard let x = anyValue as? CustomShape? else {
                throw StitchAIManagerError.typeCasting
            }
            return .shape(x)
        case .scrollJumpStyle:
            guard let x = anyValue as? ScrollJumpStyle else {
                throw StitchAIManagerError.typeCasting
            }
            return .scrollJumpStyle(x)
        case .scrollDecelerationRate:
            guard let x = anyValue as? ScrollDecelerationRate else {
                throw StitchAIManagerError.typeCasting
            }
            return .scrollDecelerationRate(x)
        case .delayStyle:
            guard let x = anyValue as? DelayStyle else {
                throw StitchAIManagerError.typeCasting
            }
            return .delayStyle(x)
        case .shapeCoordinates:
            guard let x = anyValue as? ShapeCoordinates else {
                throw StitchAIManagerError.typeCasting
            }
            return .shapeCoordinates(x)
        case .shapeCommandType:
            guard let x = anyValue as? ShapeCommandType else {
                throw StitchAIManagerError.typeCasting
            }
            return .shapeCommandType(x)
        case .shapeCommand:
            guard let x = anyValue as? ShapeCommand else {
                throw StitchAIManagerError.typeCasting
            }
            return .shapeCommand(x)
        case .orientation:
            guard let x = anyValue as? StitchOrientation else {
                throw StitchAIManagerError.typeCasting
            }
            return .orientation(x)
        case .cameraOrientation:
            guard let x = anyValue as? StitchCameraOrientation else {
                throw StitchAIManagerError.typeCasting
            }
            return .cameraOrientation(x)
        case .deviceOrientation:
            guard let x = anyValue as? StitchDeviceOrientation else {
                throw StitchAIManagerError.typeCasting
            }
            return .deviceOrientation(x)
        case .vnImageCropOption:
            guard let x = anyValue as? VNImageCropAndScaleOption else {
                throw StitchAIManagerError.typeCasting
            }
            return .vnImageCropOption(x)
        case .textDecoration:
            guard let x = anyValue as? LayerTextDecoration else {
                throw StitchAIManagerError.typeCasting
            }
            return .textDecoration(x)
        case .textFont:
            guard let x = anyValue as? StitchFont else {
                throw StitchAIManagerError.typeCasting
            }
            return .textFont(x)
        case .blendMode:
            guard let x = anyValue as? StitchBlendMode else {
                throw StitchAIManagerError.typeCasting
            }
            return .blendMode(x)
        case .mapType:
            guard let x = anyValue as? StitchMapType else {
                throw StitchAIManagerError.typeCasting
            }
            return .mapType(x)
        case .progressIndicatorStyle:
            guard let x = anyValue as? ProgressIndicatorStyle else {
                throw StitchAIManagerError.typeCasting
            }
            return .progressIndicatorStyle(x)
        case .mobileHapticStyle:
            guard let x = anyValue as? MobileHapticStyle else {
                throw StitchAIManagerError.typeCasting
            }
            return .mobileHapticStyle(x)
        case .strokeLineCap:
            guard let x = anyValue as? StrokeLineCap else {
                throw StitchAIManagerError.typeCasting
            }
            return .strokeLineCap(x)
        case .strokeLineJoin:
            guard let x = anyValue as? StrokeLineJoin else {
                throw StitchAIManagerError.typeCasting
            }
            return .strokeLineJoin(x)
        case .contentMode:
            guard let x = anyValue as? StitchContentMode else {
                throw StitchAIManagerError.typeCasting
            }
            return .contentMode(x)
        case .spacing:
            guard let x = anyValue as? StitchSpacing else {
                throw StitchAIManagerError.typeCasting
            }
            return .spacing(x)
        case .padding:
            guard let x = anyValue as? StitchPadding else {
                throw StitchAIManagerError.typeCasting
            }
            return .padding(x)
        case .sizingScenario:
            guard let x = anyValue as? SizingScenario else {
                throw StitchAIManagerError.typeCasting
            }
            return .sizingScenario(x)
        case .deviceAppearance:
            guard let x = anyValue as? DeviceAppearance else {
                throw StitchAIManagerError.typeCasting
            }
            return .deviceAppearance(x)
        case .materialThickness:
            guard let x = anyValue as? MaterialThickness else {
                throw StitchAIManagerError.typeCasting
            }
            return .materialThickness(x)
        case .anchorEntity:
            guard let x = anyValue as? UUID? else {
                throw StitchAIManagerError.typeCasting
            }
            return .anchorEntity(x)
        case .pinToId:
            guard let x = anyValue as? PinToId else {
                throw StitchAIManagerError.typeCasting
            }
            return .pinTo(x)
        case .none:
            fatalError()
        }
    }
}
