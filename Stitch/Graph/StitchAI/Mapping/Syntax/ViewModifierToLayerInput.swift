//
//  ViewModifierToLayerInputMapping.swift
//  Stitch
//
//  Created on 6/23/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI

/// Maps ViewModifierKind cases to LayerInputPort_V32 cases based on the Layer_V32 type
/// Returns the appropriate LayerInputPort_V32 for a given ViewModifierKind and Layer_V32 combination
/// - Parameters:
///   - modifier: The ViewModifierKind to map
///   - layer: The Layer_V32 type to map for
/// - Returns: The corresponding LayerInputPort_V32 if a mapping exists, nil otherwise
func mapModifierToLayerInput(modifier: ModifierKind,
                             layer: Layer) -> LayerInputPort? {
    switch modifier {
    case .scaleEffect:
        // Scale effect maps to scale input for text, rectangle, and image layers
        switch layer {
        case .text, .rectangle, .image:
            return .scale
        default:
            return nil // No mapping for other layer types yet
        }
        
        // Add additional ViewModifierKind cases here as needed
        // case .opacity:
        //     return .opacity  // Example of another potential mapping
        
    default:
        return nil // No mapping defined for this modifier
    }
}

/// Checks if a specific layer type supports a given LayerInputPort
/// - Parameters:
///   - layerInputPort: The LayerInputPort to check for support
///   - layer: The Layer_V32 type to check
/// - Returns: Boolean indicating if the layer supports the input port
@MainActor
func layerSupportsInput(layerInputPort: LayerInputPort, layer: Layer) -> Bool {
    switch layer {
    case .text:
        return TextLayerNode.inputDefinitions.contains(where: { $0 == layerInputPort })
    case .rectangle:
        return RectangleLayerNode.inputDefinitions.contains(where: { $0 == layerInputPort })
    case .image:
        return ImageLayerNode.inputDefinitions.contains(where: { $0 == layerInputPort })
    default:
        return false
    }
}
