//
//  PatchDescription.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/23.
//

import Foundation
import StitchSchemaKit

extension Patch {

    var nodeDescription: String {
        // Add new line
        "\n\(self.nodeDescriptionBody)"
    }

    var nodeDescriptionBody: String {
        switch self {
        case .splitter:
            return splitterDescription
        case .add:
            return addDescription
        case .convertPosition:
            return convertPositionDescription
        case .dragInteraction:
            return dragInteractionDescription
        case .pressInteraction:
            return pressInteractionDescription
        case .scrollInteraction:
            return scrollInteractionDescription
        case .repeatingPulse:
            return repeatingPulseDescription
        case .delay:
            return delayDescription
        case .pack:
            return packDescription
        case .unpack:
            return unpackDescription
        case .counter:
            return counterDescription
        case .flipSwitch:
            return flipSwitchDescription
        case .multiply:
            return multiplyDescription
        case .optionPicker:
            return optionPickerDescription
        case .loop:
            return loopDescription
        case .time:
            return timeDescription
        case .deviceTime:
            return deviceTimeDescription
        case .location:
            return locationDescription
        case .random:
            return randomDescription
        case .greaterOrEqual:
            return greaterOrEqualDescription
        case .lessThanOrEqual:
            return lessThanOrEqualDescription
        case .equals:
            return equalsDescription
        case .restartPrototype:
            return restartPrototypeDescription
        case .divide:
            return divideDescription
        case .hslColor:
            return hslColorDescription
        case .or:
            return orDescription
        case .and:
            return andDescription
        case .not:
            return notDescription
        case .springAnimation:
            return springAnimationDescription
        case .popAnimation:
            return popAnimationDescription
        case .bouncyConverter:
            return bouncyConverterDescription
        case .optionSwitch:
            return optionSwitchDescription
        //        case .soundKit:
        //            return soundKitDescription
        case .pulseOnChange:
            return pulseOnChangeDescription
        case .pulse:
            return pulseDescription
        case .classicAnimation:
            return classicAnimationDescription
        case .cubicBezierAnimation:
            return cubicBezierAnimationDescription
        case .curve:
            return curveDescription
        case .cubicBezierCurve:
            return cubicBezierCurveDescription
        case .repeatingAnimation:
            return repeatingAnimationDescription
        case .loopBuilder:
            return loopBuilderDescription
        case .loopInsert:
            return loopInsertDescription
        case .coreMLClassify:
            return coreMLClassifyDescription
        case .coreMLDetection:
            return coreMLDetectionDescription
        case .transition:
            return transitionDescription
        case .imageImport:
            return imageImportDescription
        case .cameraFeed:
            return cameraFeedDescription
        case .model3DImport:
            return model3DImportDescription
        case .arRaycasting:
            return arRaycastingDescription
        case .arAnchor:
            return arAnchorDescription
        case .sampleAndHold:
            return sampleHoldDescription
        case .grayscale:
            return grayscaleDescription
        case .loopSelect:
            return loopSelectDescription
        case .videoImport:
            return videoImportDescription
        case .sampleRange:
            return sampleRangeDescription
        case .soundImport:
            return soundImportDescription
        case .speaker:
            return speakerDescription
        case .microphone:
            return microphoneDescription
        case .networkRequest:
            return networkRequestDescription
        case .valueForKey:
            return valueForKeyDescription
        case .valueAtIndex:
            return valueAtIndexDescription
        case .loopOverArray:
            return loopOverArrayDescription
        case .setValueForKey:
            return setValueForKeyDescription
        case .jsonObject:
            return jsonObjectDescription
        case .jsonArray:
            return jsonArrayDescription
        case .arrayAppend:
            return arrayAppendDescription
        case .arrayCount:
            return arrayCountDescription
        case .arrayJoin:
            return arrayJoinDescription
        case .arrayReverse:
            return arrayReverseDescription
        case .arraySort:
            return arraySortDescription
        case .getKeys:
            return getKeysDescription
        case .indexOf:
            return indexOfDescription
        case .subarray:
            return subarrayDescription
        case .valueAtPath:
            return valueAtPathDescription
        case .deviceMotion:
            return deviceMotionDescription
        case .deviceInfo:
            return deviceInfoDescription
        case .smoothValue:
            return smoothValueDescription
        case .velocity:
            return velocityDescription
        case .clip:
            return clipDescription
        case .max:
            return maxDescription
        case .mod:
            return modDescription
        case .absoluteValue:
            return absoluteValueDescription
        case .round:
            return roundDescription
        case .progress:
            return progressDescription
        case .reverseProgress:
            return reverseProgressDescription
        case .wirelessBroadcaster:
            return wirelessBroadcasterDescription
        case .wirelessReceiver:
            return wirelessReceiverDescription
        case .rgba:
            return rgbaDescription
        case .arcTan2:
            return arcTan2Description
        case .sine:
            return sineDescription
        case .cosine:
            return cosineDescription
        case .hapticFeedback:
            return hapticFeedbackDescription
        case .imageToBase64String:
            return imageToBase64StringDescription
        case .base64StringToImage:
            return base64StringToImageDescription
        case .whenPrototypeStarts:
            return whenPrototypeStartsDescription
        case .soulver:
            return soulverDescription
        case .optionEquals:
            return optionEqualsDescription
        case .subtract:
            return subtractDescription
        case .squareRoot:
            return squareRootDescription
        case .length:
            return lengthDescription
        case .min:
            return minDescription
        case .power:
            return powerDescription
        case .equalsExactly:
            return equalsExactlyDescription
        case .greaterThan:
            return greaterThanDescription
        case .lessThan:
            return lessThanDescription
        case .colorToHSL:
            return colorToHSLDescription
        case .colorToHex:
            return colorToHexDescription
        case .colorToRGB:
            return colorToRGBDescription
        case .hexColor:
            return hexColorDescription
        case .splitText:
            return splitTextDescription
        case .textEndsWith:
            return textEndsWithDescription
        case .textLength:
            return textLengthDescription
        case .textReplace:
            return textReplaceDescription
        case .textStartsWith:
            return textStartsWithDescription
        case .textTransform:
            return textTransformDescription
        case .trimText:
            return trimTextDescription
        case .dateAndTimeFormatter:
            return dateAndTimeFormatterDescription
        case .stopwatch:
            return stopwatchDescription
        case .optionSender:
            return optionSenderDescription
        case .any:
            return anyDescription
        case .loopCount:
            return loopCountDescription
        case .loopDedupe:
            return loopDedupeDescription
        case .loopFilter:
            return loopFilterDescription
        case .loopOptionSwitch:
            return loopOptionSwitchDescription
        case .loopRemove:
            return loopRemoveDescription
        case .loopReverse:
            return loopReverseDescription
        case .loopShuffle:
            return loopShuffleDescription
        case .loopSum:
            return loopSumDescription
        case .loopToArray:
            return loopToArrayDescription
        case .runningTotal:
            return runningTotalDescription
        case .layerInfo:
            return layerInfoDescription
        case .triangleShape:
            return triangleShapeDescription
        case .circleShape:
            return circleShapeDescription
        case .ovalShape:
            return ovalShapeDescription
        case .roundedRectangleShape:
            return roundedRectangleShapeDescription
        case .union:
            return unionDescription
        case .keyboard:
            return keyboardDescription
        case .jsonToShape:
            return jsonToShapeDescription
        case .shapeToCommands:
            return shapeToCommandsDescription
        case .commandsToShape:
            return commandsToShapeDescription
        case .mouse:
            return mouseInteractionDescription
        case .sizePack:
            return sizePackDescription
        case .sizeUnpack:
            return sizeUnpackDescription
        case .positionPack:
            return positionPackDescription
        case .positionUnpack:
            return positionUnpackDescription
        case .point3DPack:
            return point3DPackDescription
        case .point3DUnpack:
            return point3DUnpackDescription
        case .point4DPack:
            return point4DPackDescription
        case .point4DUnpack:
            return point4DUnpackDescription
        case .transformPack:
            return transformPackDescription
        case .transformUnpack:
            return transformUnpackDescription
        case .closePath:
            return closePathDescription
        case .moveToPack:
            return moveToPackDescription
        case .lineToPack:
            return lineToPackDescription
        case .curveToPack:
            return curveToPackDescription
        case .curveToUnpack:
            return curveToUnpackDescription
        case .mathExpression:
            return mathExpressionDescription
        case .qrCodeDetection:
            return qrCodeDetectionDescription
        }

    }
}
