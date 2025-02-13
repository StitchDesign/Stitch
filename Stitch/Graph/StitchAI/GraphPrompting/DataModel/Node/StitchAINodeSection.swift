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
    static func getAllAIDescriptions() throws -> [StitchAINodeSectionDescription] {
        try Self.allCases.map(StitchAINodeSectionDescription.init)
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
    /// Returns the section header that this Patch case belongs to.
    var section: NodeSection {
        switch self {
        // MARK: General Nodes
        case .splitter, .random, .counter, .flipSwitch:
            return .general
            
        // MARK: Math Operation Nodes
        case .absoluteValue, .add, .max, .min, .mod, .multiply, .power, .round, .squareRoot, .subtract:
            return .mathOperation
            
        // MARK: Comparison Nodes
        case .equals, .equalsExactly, .greaterOrEqual, .lessThanOrEqual, .greaterThan, .lessThan:
            return .comparison
            
        // MARK: Animation Nodes
        case .springAnimation, .popAnimation, .classicAnimation, .cubicBezierAnimation, .curve, .cubicBezierCurve, .repeatingAnimation:
            return .animation
            
        // MARK: Pulse Nodes
        case .pulse, .pulseOnChange, .repeatingPulse, .restartPrototype:
            return .pulse
            
        // MARK: Shape Nodes
        case .triangleShape, .circleShape, .ovalShape, .roundedRectangleShape, .union, .shapeToCommands, .commandsToShape:
            return .shape
            
        // MARK: Text Nodes
        case .textTransform, .textLength, .textReplace, .splitText, .textStartsWith, .textEndsWith, .trimText:
            return .text
            
        // MARK: Media Nodes
        case .cameraFeed, .grayscale, .soundImport, .speaker, .microphone, .videoImport, .imageImport, .imageToBase64String, .base64StringToImage:
            return .media
            
        // MARK: Position and Transform Nodes
        case .convertPosition, .transformPack, .transformUnpack, .positionPack, .point3DPack, .point4DPack:
            return .positionTransform
            
        // MARK: Interaction Nodes
        case .dragInteraction, .pressInteraction, .scrollInteraction:
            return .interaction
            
        // MARK: JSON and Array Nodes
        case .networkRequest, .jsonObject, .jsonArray, .arrayAppend, .arrayCount, .arrayJoin, .arrayReverse, .arraySort, .getKeys, .indexOf, .subarray, .valueAtPath, .setValueForKey:
            return .jsonArray
            
        // MARK: Loop Nodes
        case .loop, .loopBuilder, .loopInsert, .loopOptionSwitch, .loopRemove, .loopReverse, .loopShuffle, .loopSum, .loopToArray, .runningTotal, .loopCount, .loopDedupe, .loopFilter:
            return .loop
            
        // MARK: Utility Nodes
        case .layerInfo, .hapticFeedback, .springFromDurationAndBounce, .springFromResponseAndDampingRatio, .springFromSettlingDurationAndDampingRatio:
            return .utility
            
        // Fallback
        default:
            return .general
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
