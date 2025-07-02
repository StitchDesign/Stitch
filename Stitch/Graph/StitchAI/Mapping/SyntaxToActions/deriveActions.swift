//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI


extension SyntaxView {
    func deriveStitchActions() throws -> CurrentAIPatchBuilderResponseFormat.LayerData {
        
        // ───────────────────────────────────────────────────────────────────
        // Special‑case: ScrollView that directly wraps a single V/H/ZStack
        // ───────────────────────────────────────────────────────────────────
        if self.name == .scrollView {
            do {
                if let result = try handleScrollView() {
                    return result
                }
                // No `else`, since it's okay for this view not to be a scroll view
            } catch {
                throw error
            }
        }
        
        // Instantiate with empty data
        var data = CurrentAIPatchBuilderResponseFormat
            .LayerData(layers: [],
                       custom_layer_input_values: [])
                
        // 1. Map this node
        var layerData = try self.name.deriveLayerData(
            id: self.id,
            args: self.constructorArguments,
            modifiers: self.modifiers)
        
        data.custom_layer_input_values += layerData.customLayerInputValues
        
        var childLayers: [CurrentAIPatchBuilderResponseFormat.LayerNode] = []
        
        // 2. Recurse into children
        for child in children {
            // depth-first
            let childConcepts = try child.deriveStitchActions()
            // Append child layers directly to layer at this recursive level
            childLayers += childConcepts.layers
            
            data.custom_layer_input_values += childConcepts.custom_layer_input_values
            
        }
        
        if !childLayers.isEmpty {
            layerData.node.children = childLayers
        }
        
        data.layers.append(layerData.node)
        
        return data
    }
}

extension SyntaxView {
    /// Handles ScrollView-specific logic including axis detection and scroll behavior
    func handleScrollView() throws -> CurrentAIPatchBuilderResponseFormat.LayerData? {
        // Check the scroll axis from constructor arguments
        let scrollAxis = detectScrollAxis()
        
        // Only proceed if we have a valid scroll axis and a single stack child
        guard 
            scrollAxis != .none,
            children.count == 1,
            let stack = children.first,
            // TODO: support `.lazyVGrid` as well
            (stack.name == .vStack || stack.name == .hStack || stack.name == .zStack)
        else {
            // Fall back to default handling if structure doesn't match expected pattern
            return nil
        }
        
        var flattened = try stack.deriveStitchActions()
        
        // The leading layer from the stack mapping is the group layer
        if let groupLayer = flattened.layers.first {
            // Enable the appropriate scroll direction(s) based on the detected axis
            let nodeID = groupLayer.node_id.value
            
            switch scrollAxis {
            case .vertical:
                // Enable vertical scrolling only
                flattened.custom_layer_input_values.append(
                    .init(id: nodeID, input: .scrollYEnabled, value: .bool(true))
                )
                
            case .horizontal:
                // Enable horizontal scrolling only
                flattened.custom_layer_input_values.append(
                    .init(id: nodeID, input: .scrollXEnabled, value: .bool(true))
                )
                
            case .both:
                // Enable both horizontal and vertical scrolling
                flattened.custom_layer_input_values.append(contentsOf: [
                    .init(id: nodeID, input: .scrollXEnabled, value: .bool(true)),
                    .init(id: nodeID, input: .scrollYEnabled, value: .bool(true))
                ])
                
            case .none:
                // No scrolling enabled
                break
            }
        }
        
        return flattened
    }
    
    // Note: this was written very verbosely, but acceptably
    
    /// Detects the scroll axis from the ScrollView's constructor arguments
    private func detectScrollAxis() -> ScrollAxis {
        // First check for array expressions that explicitly list both axes
        for arg in constructorArguments {
            guard let firstValue = arg.values.first else { continue }
            
            // Check for array containing both axes
            if firstValue.value == "[.horizontal, .vertical]" || 
               firstValue.value == "[.vertical, .horizontal]" ||
               firstValue.value == "[Axis.horizontal, Axis.vertical]" ||
               firstValue.value == "[Axis.vertical, Axis.horizontal]" {
                return .both
            }
        }
        
        // Then check for individual axis specifications
        var hasVertical = false
        var hasHorizontal = false
        
        for arg in constructorArguments {
            for value in arg.values {
                // Check for vertical axis
                if [".vertical", "[.vertical]", "Axis.vertical"].contains(value.value) {
                    hasVertical = true
                }
                
                // Check for horizontal axis
                if [".horizontal", "[.horizontal]", "Axis.horizontal"].contains(value.value) {
                    hasHorizontal = true
                }
            }
        }
        
        // Determine the result based on which axes were found
        if hasVertical && hasHorizontal {
            return .both
        } else if hasVertical {
            return .vertical
        } else if hasHorizontal {
            return .horizontal
        }
        
        return .none
    }
    
    /// Represents the possible scroll axes for a ScrollView
    private enum ScrollAxis {
        case vertical
        case horizontal
        case both
        case none
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
