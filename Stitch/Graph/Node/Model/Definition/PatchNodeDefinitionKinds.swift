//
//  PatchGraphNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/21/24.
//

import Foundation
import StitchSchemaKit

extension Patch {
    
    var graphNode: (any NodeDefinition.Type)? {
        switch self {
        case .splitter:
            return SplitterPatchNode.self
            
        case .add:
            return nil
            // see note in `addPatchNode`
            //            return AddPatchNode.self
        case .convertPosition:
            return nil
        case .dragInteraction:
            return DragInteractionNode.self
        case .pressInteraction:
            return PressInteractionNode.self
        case .scrollInteraction:
            return ScrollInteractionNode.self
        case .repeatingPulse:
            return RepeatingPulseNode.self
        case .delay:
            return DelayPatchNode.self
        case .pack:
            return PackPatchNode.self
        case .unpack:
            return UnpackPatchNode.self
        case .counter:
            return CounterPatchNode.self
        case .flipSwitch:
            return SwitchNode.self
        case .multiply:
            return nil
        case .optionPicker:
            return nil
        case .loop:
            return nil
        case .time:
            return nil
        case .deviceTime:
            return nil
        case .location:
            return LocationNode.self
        case .random:
            return RandomPatchNode.self
        case .greaterOrEqual:
            return nil
        case .lessThanOrEqual:
            return nil
        case .equals:
            return nil
        case .restartPrototype:
            return nil
        case .divide:
            return nil
        case .hslColor:
            return nil
        case .or:
            return nil
        case .and:
            return nil
        case .not:
            return nil
        case .springAnimation:
            return SpringAnimationNode.self
        case .popAnimation:
            return PopAnimationNode.self
        case .bouncyConverter:
            return BouncyConverterNode.self
        case .optionSwitch:
            return OptionSwitchPatchNode.self
        case .pulseOnChange:
            return PulseOnChangeNode.self
        case .pulse:
            return PulseNode.self
        case .classicAnimation:
            return ClassicAnimationNode.self
        case .cubicBezierAnimation:
            return CubicBezierAnimationNode.self
        case .curve:
            return nil
        case .cubicBezierCurve:
            return nil
        case .repeatingAnimation:
            return RepeatingAnimationNode.self
        case .loopBuilder:
            return LoopBuilderNode.self
        case .loopInsert:
            return LoopInsertNode.self
        case .coreMLClassify:
            return CoreMLClassifyNode.self
        case .coreMLDetection:
            return CoreMLDetectionNode.self
        case .transition:
            return nil
        case .imageImport:
            return ImageImportPatchNode.self
        case .cameraFeed:
            return CameraFeedPatchNode.self
        case .arRaycasting:
            return ARRaycastingNode.self
        case .arAnchor:
            return ArAnchorNode.self
        case .sampleAndHold:
            return SampleAndHoldNode.self
        case .grayscale:
            return GrayscaleNode.self
        case .loopSelect:
            return nil
        case .videoImport:
            return VideoImportNode.self
        case .sampleRange:
            return SampleRangeNode.self
        case .soundImport:
            return SoundImportNode.self
        case .speaker:
            return nil
        case .microphone:
            return MicrophoneNode.self
        case .networkRequest:
            return nil
        case .valueForKey:
            return ValueForKeyNode.self
        case .valueAtIndex:
            return ValueAtIndexNode.self
        case .loopOverArray:
            return nil
        case .setValueForKey:
            return nil
        case .jsonObject:
            return JSONObjectNode.self
        case .jsonArray:
            return JSONArrayNode.self
        case .arrayAppend:
            return ArrayAppendNode.self
        case .arrayCount:
            return nil
        case .arrayJoin:
            return nil
        case .arrayReverse:
            return nil
        case .arraySort:
            return nil
        case .getKeys:
            return nil
        case .indexOf:
            return nil
        case .subarray:
            return nil
        case .valueAtPath:
            return ValueAtPathNode.self
        case .deviceMotion:
            return nil
        case .deviceInfo:
            return nil
        case .smoothValue:
            return SmoothValueNode.self
        case .velocity:
            return VelocityNode.self
        case .clip:
            return nil
        case .max:
            return nil
        case .mod:
            return ModNode.self
        case .absoluteValue:
            return nil
        case .round:
            return nil
        case .progress:
            return nil
        case .reverseProgress:
            return nil
        case .wirelessBroadcaster:
            return nil
        case .wirelessReceiver:
            return nil
        case .rgba:
            return nil
        case .arcTan2:
            return nil
        case .sine:
            return nil
        case .cosine:
            return nil
        case .hapticFeedback:
            return HapticFeedbackNode.self
        case .imageToBase64String:
            return ImageToBase64StringNode.self
        case .base64StringToImage:
            return Base64StringToImageNode.self
        case .whenPrototypeStarts:
            return WhenPrototypeStartsNode.self
        case .soulver:
            return nil
        case .optionEquals:
            return nil
        case .subtract:
            return nil
        case .squareRoot:
            return nil
        case .length:
            return nil
        case .min:
            return nil
        case .power:
            return nil
        case .equalsExactly:
            return nil
        case .greaterThan:
            return nil
        case .lessThan:
            return nil
        case .colorToHSL:
            return nil
        case .colorToHex:
            return nil
        case .colorToRGB:
            return nil
        case .hexColor:
            return nil
        case .splitText:
            return nil
        case .textEndsWith:
            return nil
        case .textLength:
            return nil
        case .textReplace:
            return nil
        case .textStartsWith:
            return nil
        case .textTransform:
            return nil
        case .trimText:
            return nil
        case .dateAndTimeFormatter:
            return nil
        case .stopwatch:
            return StopwatchNode.self
        case .optionSender:
            return nil
        case .any:
            return nil
        case .loopCount:
            return nil
        case .loopDedupe:
            return nil
        case .loopFilter:
            return nil
        case .loopOptionSwitch:
            return nil
        case .loopRemove:
            return nil
        case .loopReverse:
            return nil
        case .loopShuffle:
            return nil
        case .loopSum:
            return nil
        case .loopToArray:
            return nil
        case .runningTotal:
            return nil
        case .layerInfo:
            return LayerInfoPatchNode.self
        case .triangleShape:
            return nil
        case .circleShape:
            return nil
        case .ovalShape:
            return nil
        case .roundedRectangleShape:
            return nil
        case .union:
            return nil
        case .keyboard:
            return KeyboardNode.self
        case .jsonToShape:
            return nil
        case .shapeToCommands:
            return nil
        case .commandsToShape:
            return nil
        case .mouse:
            return nil
        case .sizePack:
            return SizePackPatchNode.self
        case .sizeUnpack:
            return SizeUnpackPatchNode.self
        case .positionPack:
            return PositionPackPatchNode.self
        case .positionUnpack:
            return PositionUnpackPatchNode.self
        case .point3DPack:
            return Point3DPackPatchNode.self
        case .point3DUnpack:
            return Point3DUnpackPatchNode.self
        case .point4DPack:
            return Point4DPackPatchNode.self
        case .point4DUnpack:
            return Point4DUnpackPatchNode.self
        case .transformPack:
            return TransformPackPatchNode.self
        case .transformUnpack:
            return TransformUnpackPatchNode.self
        case .closePath:
            return ClosePathPatchNode.self
        case .moveToPack:
            return MoveToPackPatchNode.self
        case .lineToPack:
            return LineToPackPatchNode.self
        case .curveToPack:
            return CurveToPackPatchNode.self
        case .curveToUnpack:
            return CurveToUnpackPatchNode.self
        case .mathExpression:
            return MathExpressionPatchNode.self
        case .qrCodeDetection:
            return QRCodeDetectionNode.self
        case .delayOne:
            return DelayOneNode.self
        case .springFromDurationAndBounce:
            return SpringFromDurationAndBounceNode.self
        case .springFromResponseAndDampingRatio:
            return SpringFromResponseAndDampingRatioNode.self
        case .springFromSettlingDurationAndDampingRatio:
            return SpringFromSettlingDurationAndDampingRatioNode.self
        }
    }
}
