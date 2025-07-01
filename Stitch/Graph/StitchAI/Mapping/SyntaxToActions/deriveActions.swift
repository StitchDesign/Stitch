//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI


extension SyntaxView {
    func deriveStitchActions() throws -> CurrentAIPatchBuilderResponseFormat.LayerData? {
        // Instantiate with empty data
        var data = CurrentAIPatchBuilderResponseFormat
            .LayerData(layers: [],
                       custom_layer_input_values: [])
        
        // 1. Map this node
        guard var layerData = try self.name.deriveLayer(
            id: self.id,
            args: self.constructorArguments,
            modifiers: self.modifiers) else {
            return nil
        }
        
        data.custom_layer_input_values += layerData.customLayerInputValues
        
        var childLayers: [CurrentAIPatchBuilderResponseFormat.LayerNode] = []
        
        // 2. Recurse into children
        for child in children {
            // depth-first
            if let childConcepts = try child.deriveStitchActions() {
                // Append child layers directly to layer at this recursive level
                childLayers += childConcepts.layers
                
                data.custom_layer_input_values += childConcepts.custom_layer_input_values
            }
        }
        
        if !childLayers.isEmpty {
            layerData.node.children = childLayers
        }
        
        data.layers.append(layerData.node)
        
        return data
    }
}


// https://developer.apple.com/documentation/swiftui/color#Getting-standard-colors
extension Color {
    /// Converts a textual system-color name (“yellow”, “.yellow”, “Color.yellow”)
    /// into a `SwiftUI.Color`. Returns `nil` for unknown names.
    static func fromSystemName(_ raw: String) -> Color? {
        // ── 1. Normalise ────────────────────────────────────────────────────────
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("Color.") { key.removeFirst("Color.".count) }
        if key.hasPrefix(".")      { key.removeFirst() }

        // ── 2. Lookup ───────────────────────────────────────────────────────────
        switch key.lowercased() {
        case "black":   return .black
        case "blue":    return .blue
        case "brown":   return .brown
        case "clear":   return .clear
        case "cyan":    return .cyan
        case "gray",    // US spelling
             "grey":    // convenience UK spelling
                        return .gray
        case "green":   return .green
        case "indigo":  return .indigo
        case "mint":    return .mint
        case "orange":  return .orange
        case "pink":    return .pink
        case "purple":  return .purple
        case "red":     return .red
        case "teal":    return .teal
        case "white":   return .white
        case "yellow":  return .yellow
        default:        return nil        // not a standard color
        }
    }
}
