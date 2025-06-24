//
//  ViewModifierToLayerInputMapping.swift
//  Stitch
//
//  Created on 6/23/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI


func mapViewArgumentToLayerInputPort(_ argument: Argument,
                                     viewKind: ViewKind,
                                     layer: Layer) -> LayerInputPort? {

switch viewKind {
    
    case .image:
        if argument.label == "systemName" {
            return .systemName
        }

        // switch (argument, viewKind, layer) {
        //     case ("systemName", .image, .sfSymbol):
        //         return .systemName
        // }
   
    default:
        return nil
    }
}   


/// Maps ModifierKind cases to LayerInputPort cases based on the Layer type
/// Returns the appropriate LayerInputPort for a given ModifierKind and Layer combination
/// - Parameters:
///   - modifier: The ModifierKind to map
///   - layer: The Layer type to map for
/// - Returns: The corresponding LayerInputPort if a mapping exists, nil otherwise
func mapModifierToLayerInput(modifier: ModifierKind,
                             layer: Layer) -> LayerInputPort? {
    
    switch (modifier, layer) {
        // Universal modifiers (same for every layer)
    case (.scaleEffect, _):
        return .scale
    case (.opacity, _):
        return .opacity
    case (.offset, _):
        return .position
    case (.rotationEffect, _):
        return .rotationZ
    case (.rotation3DEffect, _):
        // Depending on the axis specified in the arguments
        // This would need argument extraction to determine X, Y, or Z
        return .rotationZ // Default to Z rotation
    case (.blur, _):
        return .blurRadius
    case (.blendMode, _):
        return .blendMode
    case (.brightness, _):
        return .brightness
    case (.colorInvert, _):
        return .colorInvert
    case (.contrast, _):
        return .contrast
    case (.hueRotation, _):
        return .hueRotation
    case (.saturation, _):
        return .saturation
        
        // Layer-specific modifiers
    case (.foregroundColor, .text):
        return .color
        
    case (.foregroundColor, let kind) where kind != .text:
        return .color

    case (.fill, _): // fill is always color
        return .color
    
//    case (.font, .text):
//        return .font
    
//    case (.fontWeight, _):
//        //            return .fontWeight
//        return nil
        
//    case (.lineSpacing, _):
//        return nil // return .lineSpacing
    
    case (.cornerRadius, _):
        return .cornerRadius
        
//    case (.shadow, _):
//        // Shadow would need to be broken down into multiple inputs:
//        // .shadowColor, .shadowRadius, .shadowOffset, .shadowOpacity
//        return .shadowRadius
        
    default:
        return nil
    }
}

/// Checks if a specific layer type supports a given LayerInputPort
/// - Parameters:
///   - layerInputPort: The LayerInputPort to check for support
///   - layer: The Layer type to check
/// - Returns: Boolean indicating if the layer supports the input port
@MainActor
func layerSupportsInput(layerInputPort: LayerInputPort, layer: Layer) -> Bool {
    layer.layerGraphNode.inputDefinitions.contains(where: { $0 == layerInputPort })
}
