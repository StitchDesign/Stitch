//
//  NodeType_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import StitchSchemaKit
import Vision

// MARK: update at cadence when Stitch AI utils update node type
extension StitchAIPortValue_V0.NodeType {
    /*
     Note: StitchAI treats certain PortValues in an LLM-friendly way, e.g.
     - Color as a hex
     - CGPoint as a dictionary/json-object instead of a tuple
     */
    var portValueTypeForStitchAI: Decodable.Type {
        switch self {
        case .int:
            fatalErrorIfDebug()
            return Int.self
        case .string:
            return String.self
        case .bool:
            return Bool.self
        case .number:
            return Double.self
        case .layerDimension:
            return StitchAISizeDimension_V0.StitchAISizeDimension.self
        case .transform:
            return StitchAIPortValue_V0.PortValueVersion.StitchTransform.self
        case .plane:
            return StitchAIPortValue_V0.PortValueVersion.Plane.self
        case .networkRequestType:
            return StitchAIPortValue_V0.PortValueVersion.NetworkRequestType.self
        case .color:
            return StitchAIColor.self
        case .size:
            return StitchAISize.self
        case .position:
            return StitchAIPosition.self
        case .point3D:
            return StitchAIPortValue_V0.PortValueVersion.Point3D.self
        case .point4D:
            return StitchAIPortValue_V0.PortValueVersion.Point4D.self
        case .pulse:
            return TimeInterval.self
        case .media:
            return StitchAIPortValue_V0.PortValueVersion.AsyncMediaValue?.self
        case .json:
            return StitchAIPortValue_V0.PortValueVersion.StitchJSON.self
        case .anchoring:
            return StitchAIPortValue_V0.PortValueVersion.Anchoring.self
        case .cameraDirection:
            return StitchAIPortValue_V0.PortValueVersion.CameraDirection.self
        case .interactionId:
            return StitchAIUUID?.self
        case .scrollMode:
            return StitchAIPortValue_V0.PortValueVersion.ScrollMode.self
        case .textAlignment:
            return StitchAIPortValue_V0.PortValueVersion.LayerTextAlignment.self
        case .textVerticalAlignment:
            return StitchAIPortValue_V0.PortValueVersion.LayerTextVerticalAlignment.self
        case .fitStyle:
            return StitchAIPortValue_V0.PortValueVersion.VisualMediaFitStyle.self
        case .animationCurve:
            return StitchAIPortValue_V0.PortValueVersion.ClassicAnimationCurve.self
        case .lightType:
            return StitchAIPortValue_V0.PortValueVersion.LightType.self
        case .layerStroke:
            return StitchAIPortValue_V0.PortValueVersion.LayerStroke.self
        case .textTransform:
            return StitchAIPortValue_V0.PortValueVersion.TextTransform.self
        case .dateAndTimeFormat:
            return StitchAIPortValue_V0.PortValueVersion.DateAndTimeFormat.self
        case .shape:
            return StitchAIPortValue_V0.PortValueVersion.CustomShape?.self
        case .scrollJumpStyle:
            return StitchAIPortValue_V0.PortValueVersion.ScrollJumpStyle.self
        case .scrollDecelerationRate:
            return StitchAIPortValue_V0.PortValueVersion.ScrollDecelerationRate.self
        case .delayStyle:
            return StitchAIPortValue_V0.PortValueVersion.DelayStyle.self
        case .shapeCoordinates:
            return StitchAIPortValue_V0.PortValueVersion.ShapeCoordinates.self
        case .shapeCommandType:
            return StitchAIPortValue_V0.PortValueVersion.ShapeCommandType.self
        case .shapeCommand:
            return StitchAIPortValue_V0.PortValueVersion.ShapeCommand.self
        case .orientation:
            return StitchAIPortValue_V0.PortValueVersion.StitchOrientation.self
        case .cameraOrientation:
            return StitchAIPortValue_V0.PortValueVersion.StitchCameraOrientation.self
        case .deviceOrientation:
            return StitchAIPortValue_V0.PortValueVersion.StitchDeviceOrientation.self
        case .vnImageCropOption:
            return VNImageCropAndScaleOption.self
        case .textDecoration:
            return StitchAIPortValue_V0.PortValueVersion.LayerTextDecoration.self
        case .textFont:
            return StitchAIPortValue_V0.PortValueVersion.StitchFont.self
        case .blendMode:
            return StitchAIPortValue_V0.PortValueVersion.StitchBlendMode.self
        case .mapType:
            return StitchAIPortValue_V0.PortValueVersion.StitchMapType.self
        case .progressIndicatorStyle:
            return StitchAIPortValue_V0.PortValueVersion.ProgressIndicatorStyle.self
        case .mobileHapticStyle:
            return StitchAIPortValue_V0.PortValueVersion.MobileHapticStyle.self
        case .strokeLineCap:
            return StitchAIPortValue_V0.PortValueVersion.StrokeLineCap.self
        case .strokeLineJoin:
            return StitchAIPortValue_V0.PortValueVersion.StrokeLineJoin.self
        case .contentMode:
            return StitchAIPortValue_V0.PortValueVersion.StitchContentMode.self
        case .spacing:
            return StitchAIPortValue_V0.PortValueVersion.StitchSpacing.self
        case .padding:
            return StitchAIPortValue_V0.PortValueVersion.StitchPadding.self
        case .sizingScenario:
            return StitchAIPortValue_V0.PortValueVersion.SizingScenario.self
        case .deviceAppearance:
            return StitchAIPortValue_V0.PortValueVersion.DeviceAppearance.self
        case .materialThickness:
            return StitchAIPortValue_V0.PortValueVersion.MaterialThickness.self
        case .anchorEntity:
            return StitchAIUUID?.self
        case .pinToId:
            return StitchAIPortValue_V0.PortValueVersion.PinToId.self
            
            // TODO: enable when migrating past this version
//        case .keyboardType(let x):
//            return x
        case .none:
            fatalError()
        }
    }
    
    func coerceToPortValueForStitchAI(from anyValue: Any) throws -> StitchAIPortValue_V0.PortValue {
        switch self {
        case .int:
            fatalErrorIfDebug()
            guard let x = anyValue as? Double else {
                throw StitchAIParsingError.typeCasting
            }
            return .number(x)
        case .string:
            guard let x = anyValue as? String else {
                throw StitchAIParsingError.typeCasting
            }
            return .string(.init(x))
        case .bool:
            guard let x = anyValue as? Bool else {
                throw StitchAIParsingError.typeCasting
            }
            return .bool(x)
        case .number:
            guard let x = anyValue as? Double else {
                throw StitchAIParsingError.typeCasting
            }
            return .number(x)
        case .layerDimension:
            guard let x = anyValue as? StitchAISizeDimension else {
                throw StitchAIParsingError.typeCasting
            }
            return .layerDimension(x.value)
        case .transform:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchTransform else {
                throw StitchAIParsingError.typeCasting
            }
            return .transform(x)
        case .plane:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.Plane else {
                throw StitchAIParsingError.typeCasting
            }
            return .plane(x)
        case .networkRequestType:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.NetworkRequestType else {
                throw StitchAIParsingError.typeCasting
            }
            return .networkRequestType(x)
        case .color:
            guard let stitchAIColor = anyValue as? StitchAIColor else {
                throw StitchAIParsingError.typeCasting
            }
            return .color(stitchAIColor.value)
        case .size:
            guard let aiSize = anyValue as? StitchAISize else {
                throw StitchAIParsingError.typeCasting
            }
            
            let size = CurrentStitchAIPortValue
                .LayerSize(width: aiSize.width.value,
                           height: aiSize.height.value)
            
            return .size(size)
        case .position:
            guard let x = anyValue as? StitchAIPosition else {
                throw StitchAIParsingError.typeCasting
            }
            
            return .position(.init(x: x.x, y: x.y))
        case .point3D:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.Point3D else {
                throw StitchAIParsingError.typeCasting
            }
            return .point3D(x)
        case .point4D:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.Point4D else {
                throw StitchAIParsingError.typeCasting
            }
            return .point4D(x)
        case .pulse:
            guard let x = anyValue as? TimeInterval else {
                throw StitchAIParsingError.typeCasting
            }
            return .pulse(x)
        case .media:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.AsyncMediaValue? else {
                throw StitchAIParsingError.typeCasting
            }
            return .asyncMedia(x)
        case .json:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchJSON else {
                throw StitchAIParsingError.typeCasting
            }
            return .json(x)
        case .anchoring:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.Anchoring else {
                throw StitchAIParsingError.typeCasting
            }
            return .anchoring(x)
        case .cameraDirection:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.CameraDirection else {
                throw StitchAIParsingError.typeCasting
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
                
                throw StitchAIParsingError.typeCasting
            }
            
            if let x = x {
                return .assignedLayer(.init(x.value))
            }
            
            return .assignedLayer(nil)
            
        case .scrollMode:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ScrollMode else {
                throw StitchAIParsingError.typeCasting
            }
            return .scrollMode(x)
        case .textAlignment:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.LayerTextAlignment else {
                throw StitchAIParsingError.typeCasting
            }
            return .textAlignment(x)
        case .textVerticalAlignment:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.LayerTextVerticalAlignment else {
                throw StitchAIParsingError.typeCasting
            }
            return .textVerticalAlignment(x)
        case .fitStyle:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.VisualMediaFitStyle else {
                throw StitchAIParsingError.typeCasting
            }
            return .fitStyle(x)
        case .animationCurve:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ClassicAnimationCurve else {
                throw StitchAIParsingError.typeCasting
            }
            return .animationCurve(x)
        case .lightType:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.LightType else {
                throw StitchAIParsingError.typeCasting
            }
            return .lightType(x)
        case .layerStroke:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.LayerStroke else {
                throw StitchAIParsingError.typeCasting
            }
            return .layerStroke(x)
        case .textTransform:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.TextTransform else {
                throw StitchAIParsingError.typeCasting
            }
            return .textTransform(x)
        case .dateAndTimeFormat:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.DateAndTimeFormat else {
                throw StitchAIParsingError.typeCasting
            }
            return .dateAndTimeFormat(x)
        case .shape:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.CustomShape? else {
                throw StitchAIParsingError.typeCasting
            }
            return .shape(x)
        case .scrollJumpStyle:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ScrollJumpStyle else {
                throw StitchAIParsingError.typeCasting
            }
            return .scrollJumpStyle(x)
        case .scrollDecelerationRate:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ScrollDecelerationRate else {
                throw StitchAIParsingError.typeCasting
            }
            return .scrollDecelerationRate(x)
        case .delayStyle:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.DelayStyle else {
                throw StitchAIParsingError.typeCasting
            }
            return .delayStyle(x)
        case .shapeCoordinates:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ShapeCoordinates else {
                throw StitchAIParsingError.typeCasting
            }
            return .shapeCoordinates(x)
        case .shapeCommandType:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ShapeCommandType else {
                throw StitchAIParsingError.typeCasting
            }
            return .shapeCommandType(x)
        case .shapeCommand:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ShapeCommand else {
                throw StitchAIParsingError.typeCasting
            }
            return .shapeCommand(x)
        case .orientation:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchOrientation else {
                throw StitchAIParsingError.typeCasting
            }
            return .orientation(x)
        case .cameraOrientation:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchCameraOrientation else {
                throw StitchAIParsingError.typeCasting
            }
            return .cameraOrientation(x)
        case .deviceOrientation:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchDeviceOrientation else {
                throw StitchAIParsingError.typeCasting
            }
            return .deviceOrientation(x)
        case .vnImageCropOption:
            guard let x = anyValue as? VNImageCropAndScaleOption else {
                throw StitchAIParsingError.typeCasting
            }
            return .vnImageCropOption(x)
        case .textDecoration:
            guard let x = anyValue as? CurrentStitchAIPortValue.TextDecoration else {
                throw StitchAIParsingError.typeCasting
            }
            return .textDecoration(x)
        case .textFont:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchFont else {
                throw StitchAIParsingError.typeCasting
            }
            return .textFont(x)
        case .blendMode:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchBlendMode else {
                throw StitchAIParsingError.typeCasting
            }
            return .blendMode(x)
        case .mapType:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchMapType else {
                throw StitchAIParsingError.typeCasting
            }
            return .mapType(x)
        case .progressIndicatorStyle:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.ProgressIndicatorStyle else {
                throw StitchAIParsingError.typeCasting
            }
            return .progressIndicatorStyle(x)
        case .mobileHapticStyle:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.MobileHapticStyle else {
                throw StitchAIParsingError.typeCasting
            }
            return .mobileHapticStyle(x)
        case .strokeLineCap:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StrokeLineCap else {
                throw StitchAIParsingError.typeCasting
            }
            return .strokeLineCap(x)
        case .strokeLineJoin:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StrokeLineJoin else {
                throw StitchAIParsingError.typeCasting
            }
            return .strokeLineJoin(x)
        case .contentMode:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchContentMode else {
                throw StitchAIParsingError.typeCasting
            }
            return .contentMode(x)
        case .spacing:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchSpacing else {
                throw StitchAIParsingError.typeCasting
            }
            return .spacing(x)
        case .padding:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.StitchPadding else {
                throw StitchAIParsingError.typeCasting
            }
            return .padding(x)
        case .sizingScenario:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.SizingScenario else {
                throw StitchAIParsingError.typeCasting
            }
            return .sizingScenario(x)
        case .deviceAppearance:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.DeviceAppearance else {
                throw StitchAIParsingError.typeCasting
            }
            return .deviceAppearance(x)
        case .materialThickness:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.MaterialThickness else {
                throw StitchAIParsingError.typeCasting
            }
            return .materialThickness(x)
        case .anchorEntity:
            guard let stitchUUID = anyValue as? StitchAIUUID? else {
                if let xString = anyValue as? String, xString == "None" {
                    return .anchorEntity(nil)
                }
                throw StitchAIParsingError.typeCasting
            }
            return .anchorEntity(stitchUUID?.value)
        case .pinToId:
            guard let x = anyValue as? StitchAIPortValue_V0.PortValueVersion.PinToId else {
                throw StitchAIParsingError.typeCasting
            }
            return .pinTo(x)
            
            // TODO: enable when migrating past this version
//        case .keyboardType:
//            guard let x = anyValue as? KeyboardType else {
//                throw StitchAIParsingError.typeCasting
//            }
//            return .keyboardType(x)
        case .none:
            fatalError()
        }
    }
}
