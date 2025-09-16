//
//  NodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/29/22.
//

import Foundation
import StitchSchemaKit

extension NodeKind {
    var isSpeakerNode: Bool {
        self == .patch(.speaker)
    }

    /// Returns true if video or image layer node.
    var isVisualMediaNode: Bool {
        switch self {
        case .patch(let patch):
            switch patch {
            case .imageImport, .grayscale, .videoImport, .cameraFeed:
                return true
    
            default:
                return false
            }
            
        case .layer:
            return self.isVisualMediaLayerNode
            
        default:
            return false
        }
    }
    
    var isVisualMediaLayerNode: Bool {
        self == .layer(.image) || self == .layer(.video)
    }
}

let fakeNodeId: UUID = .randomNodeId

extension Patch {
    // TODO: longer term solution: update `asyncMediaEvalOp` to handle empty outputs (or find another way to address various graph reset issues)
    var isMediaPatch: Bool {
        switch self {
        case .speaker, .imageImport, .videoImport, .cameraFeed, .grayscale, .coreMLClassify, .coreMLDetection, .imageToBase64String, .base64StringToImage, .microphone:
            return true
                
        case .splitter, .add, .convertPosition, .dragInteraction, .pressInteraction, .scrollInteraction, .repeatingPulse, .delay, .pack, .unpack, .counter, .flipSwitch, .multiply, .optionPicker, .loop, .time, .deviceTime, .location, .random, .greaterOrEqual, .lessThanOrEqual, .equals, .restartPrototype, .divide, .hslColor, .or, .and, .not, .springAnimation, .popAnimation, .bouncyConverter, .optionSwitch, .pulseOnChange, .pulse, .classicAnimation, .cubicBezierAnimation, .curve, .cubicBezierCurve, .repeatingAnimation, .loopBuilder, .loopInsert, .transition, .arRaycasting, .arAnchor, .sampleAndHold, .loopSelect, .sampleRange, .soundImport, .networkRequest, .valueForKey, .valueAtIndex, .loopOverArray, .setValueForKey, .jsonObject, .jsonArray, .arrayAppend, .arrayCount, .arrayJoin, .arrayReverse, .arraySort, .getKeys, .indexOf, .subarray, .valueAtPath, .deviceMotion, .deviceInfo, .smoothValue, .velocity, .clip, .max, .mod, .absoluteValue, .round, .progress, .reverseProgress, .wirelessBroadcaster, .wirelessReceiver, .rgba, .arcTan2, .sine, .cosine, .hapticFeedback, .whenPrototypeStarts, .soulver, .optionEquals, .subtract, .squareRoot, .length, .min, .power, .equalsExactly, .greaterThan, .lessThan, .colorToHSL, .colorToHex, .colorToRGB, .hexColor, .splitText, .textEndsWith, .textLength, .textReplace, .textStartsWith, .textTransform, .trimText, .dateAndTimeFormatter, .stopwatch, .optionSender, .any, .loopCount, .loopDedupe, .loopFilter, .loopOptionSwitch, .loopRemove, .loopReverse, .loopShuffle, .loopSum, .loopToArray, .runningTotal, .layerInfo, .triangleShape, .circleShape, .ovalShape, .roundedRectangleShape, .union, .keyboard, .jsonToShape, .shapeToCommands, .commandsToShape, .mouse, .sizePack, .sizeUnpack, .positionPack, .positionUnpack, .point3DPack, .point3DUnpack, .point4DPack, .point4DUnpack, .transformPack, .transformUnpack, .closePath, .moveToPack, .lineToPack, .curveToPack, .curveToUnpack, .mathExpression, .qrCodeDetection, .delayOne, .springFromDurationAndBounce, .springFromResponseAndDampingRatio, .springFromSettlingDurationAndDampingRatio, .javascript:
            return false
            
        }
    }
}
