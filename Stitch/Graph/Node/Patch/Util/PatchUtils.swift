//
//  Patch.swift
//  Stitch
//
//  Created by cjc on 2/3/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

/* ----------------------------------------------------------------
 Patches: nodes on graph used for calculations etc. (not UI elements)
 ---------------------------------------------------------------- */

typealias PatchNodes = [PatchNode]

extension Patch {
    // Some nodes' eval methods draw directly from app-state (eg graph time or AVAudioRecorder) or internal node state (eg classic animation state),
    // and so their 'old vs new inputs' cannot be used to determine whether to run them.
    // Hence we always run their eval methods.
    var willAlwaysRunEval: Bool {

        switch self {

        case
            // nodes that rely on graphTime from app-state
            .time,
            .deviceTime,
            .stopwatch,
            .deviceMotion,
            .repeatingPulse,

            // TODO: only needs to run when prototype has been restarted or graph first opens?
            .whenPrototypeStarts,

            // repeatingAnimation node is something constantly checked, like a graph-time based node
            // TODO: can we come up with a better implementation?
            .repeatingAnimation,

            // nodes that (may) rely on AVPlayer metering from app-state
            // TODO: we don't need to run these nodes' evals if e.g. play=false etc.?
            .videoImport,
            .soundImport,
            .microphone,
            .sampleRange,

            // TODO: only needs to run when device orienation changes?
            .deviceInfo,

            .smoothValue, // is this an animation node?

            // TODO: only needs to run when input is changing? Is more like an animation node?
            .velocity,

            // a keyboard node's inputs might not change,
            // yet we may want to run its eval to change its outputs,
            // based on pressesBegan, etc.
            .keyboard,

            // Needs to subscribe to layer data, likely a more efficient way to do this
            .dragInteraction,
            
            .scrollInteraction:

            return true

        default:
            return false
        }
    }

    var isAnimationNode: Bool {
        switch self {
        case .classicAnimation,
             .cubicBezierAnimation,
             .repeatingAnimation,
             .springAnimation,
             .popAnimation,
             // scroll is technically an animation too
             .scrollInteraction,
            
            // NOT true for .nativeScrollInteraction ?
            
             // drag interaction's momentum is an animation
             .dragInteraction:
            return true
        default:
            return false
        }
    }

    var isARAnchor: Bool {
        switch self {
        case .arAnchor:
            return true
        default:
            return false
        }
    }

    // MARK: heavy perf cost due to human readable string.**
    func defaultDisplayTitle() -> String {
        switch self {
        case .splitter:
            return "Value"
        case .flipSwitch:
            return "Switch"
        case .arcTan2:
            return "Arc Tan 2"
        case .coreMLClassify:
            return "Image Classification"
        case .coreMLDetection:
            return "Object Detection"
        case .hslColor:
            return "HSL Color"
        case .colorToHSL:
            return "Color to HSL"
        case .rgba:
            return "RGB Color"
        case .colorToRGB:
            return "Color to RGB"
        case .arRaycasting:
            return "Raycasting"
        case .base64StringToImage:
            return "Base64 To Image"
        case .imageToBase64String:
            return "Image To Base64"
        case .whenPrototypeStarts:
            return "On Prototype Start"
        case .jsonToShape:
            return "JSON To Shape"
        case .jsonArray:
            return "JSON Array"
        case .jsonObject:
            return "JSON Object"
        case .arAnchor:
            return "AR Anchor"
        case .add:
            return "Add"
        case .convertPosition:
            return "Convert Position"
        case .dragInteraction:
            return "Drag Interaction"
        case .pressInteraction:
            return "Press Interaction"
        case .scrollInteraction:
            return "Legacy Scroll Interaction"
        case .repeatingPulse:
            return "Repeating Pulse"
        case .delay:
            return "Delay"
        case .pack:
            return "Pack"
        case .unpack:
            return "Unpack"
        case .counter:
            return "Counter"
        case .multiply:
            return "Multiply"
        case .optionPicker:
            return "Option Picker"
        case .loop:
            return "Loop"
        case .time:
            return "Time"
        case .deviceTime:
            return "Device Time"
        case .location:
            return "Location"
        case .random:
            return "Random"
        case .greaterOrEqual:
            return "Greater or Equal"
        case .lessThanOrEqual:
            return "Less Than or Equal"
        case .equals:
            return "Equals"
        case .restartPrototype:
            return "Restart Prototype"
        case .divide:
            return "Divide"
        case .or:
            return "Or"
        case .and:
            return "And"
        case .not:
            return  "Not"
        case .springAnimation:
            return "Spring Animation"
        case .popAnimation:
            return "Pop Animation"
        case .bouncyConverter:
            return "Bouncy Converter"
        case .optionSwitch:
            return "Option Switch"
        case .pulseOnChange:
            return "Pulse on Change"
        case .pulse:
            return "Pulse"
        case .classicAnimation:
            return "Classic Animation"
        case .cubicBezierAnimation:
            return "Cubic Bezier Animation"
        case .curve:
            return "Curve"
        case .cubicBezierCurve:
            return "Cubic Bezier Curve"
        case .repeatingAnimation:
            return "Repeating Animation"
        case .loopBuilder:
            return "Loop Builder"
        case .loopInsert:
            return "Loop Insert"
        case .transition:
            return "Transition"
        case .imageImport:
            return "Image Import"
        case .cameraFeed:
            return "Camera Feed"
        case .sampleAndHold:
            return "Sample and Hold"
        case .grayscale:
            return "Grayscale"
        case .loopSelect:
            return "Loop Select"
        case .videoImport:
            return "Video Import"
        case .sampleRange:
            return "Sample Range"
        case .soundImport:
            return "Sound Import"
        case .speaker:
            return "Speaker"
        case .microphone:
            return "Microphone"
        case .networkRequest:
            return "Network Request"
        case .valueForKey:
            return "Value for Key"
        case .valueAtIndex:
            return "Value at Index"
        case .loopOverArray:
            return "Loop Over Array"
        case .setValueForKey:
            return "Set Value for Key"
        case .arrayAppend:
            return "Array Append"
        case .arrayCount:
            return "Array Count"
        case .arrayJoin:
            return "Array Join"
        case .arrayReverse:
            return "Array Reverse"
        case .arraySort:
            return "Array Sort"
        case .getKeys:
            return "Get Keys"
        case .indexOf:
            return "Index Of"
        case .subarray:
            return "Sub Array"
        case .valueAtPath:
            return "Value at Path"
        case .deviceMotion:
            return "Device Motion"
        case .deviceInfo:
            return "Device Info"
        case .smoothValue:
            return "Smooth Value"
        case .velocity:
            return "Velocity"
        case .clip:
            return "Clip"
        case .max:
            return "Max"
        case .mod:
            return "Mod"
        case .absoluteValue:
            return "Absolute Value"
        case .round:
            return "Round"
        case .progress:
            return "Progress"
        case .reverseProgress:
            return "Reverse Progress"
        case .wirelessBroadcaster:
            return "Wireless Broadcaster"
        case .wirelessReceiver:
            return "Wireless Receiver"
        case .sine:
            return "Sine"
        case .cosine:
            return "Cosine"
        case .hapticFeedback:
            return "Haptic Feedback"
        case .soulver:
            return "Soulver"
        case .optionEquals:
            return "Option Equals"
        case .subtract:
            return "Subtract"
        case .squareRoot:
            return "Square Root"
        case .length:
            return "Length"
        case .min:
            return "Min"
        case .power:
            return "Power"
        case .equalsExactly:
            return "Equals Exactly"
        case .greaterThan:
            return "Greater Than"
        case .lessThan:
            return "Less Than"
        case .colorToHex:
            return "Color To Hex"
        case .hexColor:
            return "Hex Color"
        case .splitText:
            return "Split Text"
        case .textEndsWith:
            return "Text Ends With"
        case .textLength:
            return "Text Length"
        case .textReplace:
            return "Text Replace"
        case .textStartsWith:
            return "Text Starts With"
        case .textTransform:
            return "Text Transform"
        case .trimText:
            return "Trim Text"
        case .dateAndTimeFormatter:
            return "Date And Time Formatter"
        case .stopwatch:
            return "Stopwatch"
        case .optionSender:
            return "Option Sender"
        case .any:
            return "Any"
        case .loopCount:
            return "Loop Count"
        case .loopDedupe:
            return "Loop Dedupe"
        case .loopFilter:
            return "Loop Filter"
        case .loopOptionSwitch:
            return "Loop Option Switch"
        case .loopRemove:
            return "Loop Remove"
        case .loopReverse:
            return "Loop Reverse"
        case .loopShuffle:
            return "Loop Shuffle"
        case .loopSum:
            return "Loop Sum"
        case .loopToArray:
            return "Loop to Array"
        case .runningTotal:
            return "Running Total"
        case .layerInfo:
            return "Layer Info"
        case .triangleShape:
            return "Triangle Shape"
        case .circleShape:
            return "Circle Shape"
        case .ovalShape:
            return "Oval Shape"
        case .roundedRectangleShape:
            return "Rounded Rectangle Shape"
        case .union:
            return "Union"
        case .keyboard:
            return "Keyboard"
        case .shapeToCommands:
            return "Shape to Commands"
        case .commandsToShape:
            return "Commands to Shape"
        case .mouse:
            return "Mouse"
        case .qrCodeDetection:
            return "QR Code Detection"
        case .delayOne:
            return "Delay 1"
        // TODO: assume that rawValue for all patches added will have properly capitalized display-value, and so just use `default: return self.rawValue`
        case .sizePack, .sizeUnpack, .positionPack, .positionUnpack, .point3DPack, .point3DUnpack, .point4DPack, .point4DUnpack, .transformPack, .transformUnpack, .closePath, .moveToPack, .lineToPack, .curveToPack, .curveToUnpack, .mathExpression, .springFromDurationAndBounce, .springFromResponseAndDampingRatio, .springFromSettlingDurationAndDampingRatio:
            return self.rawValue
        }
    }

    
    // Previously used to filter some incomplete patches but currently we show all
    static var searchablePatches: [Patch] {
        //        Patch.allCases
        Patch.allCases.filter { patch in
            
            // TODO: Fix `SampleRange` node with media
            patch != .sampleRange
            
            // Prefer type-specific pack and unpack patches
            && patch != .pack
            && patch != .unpack
            
//            // Prefer .nativeScrollInteraction
//            && patch != .scrollInteraction
        }
    }

    func supportedMediaType(portId: Int) -> NodeMediaSupport? {
        switch self {
        case .imageImport, .grayscale:
            return .single(.image)
        case .videoImport:
            return .single(.video)
        case .soundImport, .speaker:
            return .single(.audio)
        case .coreMLClassify, .coreMLDetection:
            if portId == 0 {
                return .single(.coreML)
            } else if portId == 1 {
                return .single(.image)
            } else {
                return .single(.coreML)
            }
        case .loopBuilder, .splitter:
            return .all
        default:
            return nil
        }
    }
    
    var usesInputsForLoopIndices: Bool {
        switch self {
        case .loopToArray, .commandsToShape:
            return true
        default:
            return false
        }
    }
    
    var supportsOneToManyIO: Bool {
        switch self {
        case .coreMLDetection:
            return true
        default:
            return false
        }
    }
}
