//
//  StitchAINodeSection.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

/// An enum for grouping node types by their section header.
public enum NodeSection: String, CaseIterable, CustomStringConvertible {
    case general = "General Nodes"
    case mathOperation = "Math Operation Nodes"
    case comparison = "Comparison Nodes"
    case animation = "Animation Nodes"
    case pulse = "Pulse Nodes"
    case shape = "Shape Nodes"
    case text = "Text Nodes"
    case media = "Media Nodes"
    case positionTransform = "Position and Transform Nodes"
    case interaction = "Interaction Nodes"
    case jsonArray = "JSON and Array Nodes"
    case loop = "Loop Nodes"
    case utility = "Utility Nodes"
    case additionalMath = "Additional Math and Trigonometry Nodes"
    case additionalPack = "Additional Pack/Unpack Nodes"
    case ar3D = "AR and 3D Nodes"
    case machineLearning = "Machine Learning Nodes"
    case gradient = "Gradient Nodes"
    case layerEffect = "Layer Effect Nodes"
    case additionalLayer = "Additional Layer Nodes"
    case extensionSupport = "Extension Support Nodes"
    case progressState = "Progress and State Nodes"
    case deviceSystem = "Device and System Nodes"
    case arrayOperation = "Array Operation Nodes"
}

extension NodeSection {
    @MainActor
    static func getAllAIDescriptions() -> [StitchAINodeSectionDescription] {
        Self.allCases.map(StitchAINodeSectionDescription.init)
    }
    
    public var description: String {
        return self.rawValue
    }
    
    func getNodesForSection() -> Set<NodeKind> {
        let matchingPatches: [NodeKind] = Patch.allCases
            .filter {
                $0.section == self
            }
            .map(NodeKind.patch)
        
        let matchingLayers = Layer.allCases
            .filter {
                $0.section == self
            }
            .map(NodeKind.layer)
        
        return Set(matchingPatches + matchingLayers)
    }
}

extension NodeKind {
    var section: NodeSection {
        switch self {
        case .patch(let patch):
            return patch.section
        case .layer(let layer):
            return layer.section
        default:
            fatalError()
        }
    }
}

extension Patch {
    var section: NodeSection {
        switch self {
            // MARK: General Nodes
        case .splitter, .random, .counter, .flipSwitch:
            return .general
            
            // MARK: Math Operation Nodes
        case .add, .multiply, .divide, .absoluteValue, .round, .squareRoot,
                .subtract, .max, .min, .mod, .power, .soulver, .length,
                .mathExpression, .clip:
            return .mathOperation
            
            // MARK: Comparison Nodes
        case .greaterOrEqual, .lessThanOrEqual, .equals, .equalsExactly,
                .greaterThan, .lessThan, .or, .and, .not:
            return .comparison
            
            // MARK: Animation Nodes
        case .springAnimation, .popAnimation, .classicAnimation,
                .cubicBezierAnimation, .repeatingAnimation, .curve,
                .cubicBezierCurve, .bouncyConverter, .transition,
                .springFromDurationAndBounce, .springFromResponseAndDampingRatio,
                .springFromSettlingDurationAndDampingRatio:
            return .animation
            
            // MARK: Pulse Nodes
        case .pulse, .pulseOnChange, .repeatingPulse, .restartPrototype:
            return .pulse
            
            // MARK: Utility Nodes
        case .delay, .delayOne, .whenPrototypeStarts, .smoothValue,
                .stopwatch, .any, .hapticFeedback, .sampleAndHold, .time,
                .layerInfo, .velocity, .sampleRange,
            // Color conversion nodes are also treated as utility here.
                .hslColor, .colorToHSL, .colorToHex, .colorToRGB, .hexColor, .rgba:
            return .utility
            
            // MARK: Additional Pack/Unpack Nodes
        case .pack, .unpack, .sizePack, .sizeUnpack, .closePath,
                .moveToPack, .lineToPack, .curveToPack, .curveToUnpack:
            return .additionalPack
            
            // MARK: Position and Transform Nodes
        case .convertPosition, .positionPack, .positionUnpack,
                .point3DPack, .point3DUnpack, .point4DPack, .point4DUnpack,
                .transformPack, .transformUnpack:
            return .positionTransform
            
            // MARK: Progress and Option Nodes
        case .optionPicker, .optionSwitch, .optionEquals, .optionSender,
                .progress, .reverseProgress:
            return .progressState
            
            // MARK: Device Time and Location
        case .deviceTime, .location:
            return .deviceSystem
            
            // MARK: Interaction Nodes
        case .dragInteraction, .pressInteraction, .scrollInteraction,
                .keyboard, .mouse:
            return .interaction
            
            // MARK: Loop Nodes
        case .loop, .loopBuilder, .loopInsert, .loopSelect, .loopOverArray,
                .loopCount, .loopDedupe, .loopFilter, .loopOptionSwitch,
                .loopRemove, .loopReverse, .loopShuffle, .loopSum, .loopToArray,
                .runningTotal:
            return .loop
            
            // MARK: JSON and Array Nodes
        case .networkRequest, .jsonObject, .jsonArray:
            return .jsonArray
            
            // MARK: Device and System Nodes
        case .deviceMotion, .deviceInfo:
            return .deviceSystem
            
            // MARK: Additional Math and Trigonometry Nodes
        case .arcTan2, .sine, .cosine:
            return .additionalMath
            
            // MARK: Machine Learning Nodes
        case .coreMLClassify, .coreMLDetection:
            return .machineLearning
            
            // MARK: Extension Support Nodes
        case .wirelessBroadcaster, .wirelessReceiver:
            return .extensionSupport
            
            // MARK: Text Nodes
        case .splitText, .textEndsWith, .textLength, .textReplace,
                .textStartsWith, .textTransform, .trimText, .dateAndTimeFormatter:
            return .text
            
            // MARK: Additional Layer (Shape) Nodes
        case .triangleShape, .circleShape, .ovalShape, .roundedRectangleShape,
                .union, .jsonToShape, .shapeToCommands, .commandsToShape:
            return .additionalLayer
            
            // MARK: Media Nodes
        case .cameraFeed, .grayscale, .soundImport, .speaker, .microphone,
                .videoImport, .imageImport, .base64StringToImage, .imageToBase64String, .qrCodeDetection:
            return .media
            
            // MARK: AR and 3D Nodes
        case .arRaycasting, .arAnchor:
            return .ar3D
            
            // MARK: Array Operations
        case .arrayAppend, .arrayCount, .arrayJoin, .arrayReverse, .arraySort, .getKeys,
                .indexOf, .subarray, .setValueForKey, .valueForKey, .valueAtIndex,
                .valueAtPath:
            return .arrayOperation
        }
    }
}

extension Layer {
    /// Returns the section header that this Layer case belongs to.
    var section: NodeSection {
        switch self {
            // For text-based layers
        case .text, .textField:
            return .text
            
            // For shape-like layers
        case .oval, .rectangle, .shape:
            return .shape
            
            // For media layers
        case .image, .video, .videoStreaming:
            return .media
            
            // Grouping-related or container layers
        case .group, .canvasSketch:
            return .general
            
            // For 3D layers
        case .model3D, .realityView, .box, .sphere, .cylinder, .cone:
            return .ar3D
            
            // Additional effects or fill layers
        case .colorFill:
            return .utility
            
            // For interactive layers
        case .hitArea:
            return .interaction
            
            // Map-related layers
        case .map:
            return .media
            
            // For progress or switch type layers
        case .progressIndicator, .switchLayer:
            return .progressState
            
            // For gradient layers
        case .linearGradient, .radialGradient, .angularGradient:
            return .gradient
            
            // For symbol or material layers
        case .sfSymbol, .material:
            return .layerEffect
        }
    }
}
