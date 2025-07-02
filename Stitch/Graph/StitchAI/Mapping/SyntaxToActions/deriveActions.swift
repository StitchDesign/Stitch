//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI

struct SwiftSyntaxActionsResult {
    let actions: [CurrentAIPatchBuilderResponseFormat.LayerData]
    var caughtErrors: [SwiftUISyntaxError]
}

extension Array where Element == SyntaxView {
    func deriveStitchActions() throws -> SwiftSyntaxActionsResult {
        let allResults = try self.map { try $0.deriveStitchActions() }
        
        return .init(actions: allResults.flatMap { $0.actions },
                     caughtErrors: allResults.flatMap { $0.caughtErrors })
    }
}

extension SyntaxView {
    func deriveStitchActions() throws -> SwiftSyntaxActionsResult {
        // Recurse into children first (DFS), we might use this data for nested scenarios like ScrollView
        let childResults = try self.children.deriveStitchActions()

        // Map this node
        do {
            var layerData = try self.name.deriveLayerData(
                id: self.id,
                args: self.constructorArguments,
                modifiers: self.modifiers,
                childrenLayers: childResults.actions)
            
            guard let layer = layerData.node_name.value.layer else {
                fatalErrorIfDebug("deriveStitchActions error: no layer found for \(layerData.node_name.value)")
                throw SwiftUISyntaxError.layerDecodingFailed
            }
            
            if !layer.isGroup {
                // Make sure non-grouped layer has no children
                assertInDebug(childResults.actions.isEmpty)
                layerData.children = nil
            }
    
            return .init(actions: [layerData],
                         caughtErrors: childResults.caughtErrors)
        } catch let error as SwiftUISyntaxError {
            switch error {
            case .unsupportedLayer, .unsupportedLayerInput, .unsupportedViewModifier:
                log("deriveStitchActions: silent failure for unsupported layer concept: \(error)")
                // Silent error for unsupported layers
                var resultForSilentFailure = childResults
                resultForSilentFailure.caughtErrors.append(error)
                return resultForSilentFailure
                
            default:
                throw error
            }
        }
    }
}

extension SyntaxViewName {
    /// Handles ScrollView-specific logic including axis detection and scroll behavior
    static func createScrollGroupLayer(args: [SyntaxViewConstructorArgument],
//                                       childrenAST: [SyntaxView],
                                       childrenLayers: [CurrentAIPatchBuilderResponseFormat.LayerData]) throws -> CurrentAIPatchBuilderResponseFormat.LayerData {
        // Check the scroll axis from constructor arguments
        let scrollAxis = Self.detectScrollAxis(args: args)
      
        var groupLayer: CurrentAIPatchBuilderResponseFormat.LayerData  
        let isFirstLayerGroup = childrenLayers.first?.node_name.value.layer?.isGroup ?? false
        let hasRootGroupLayer = childrenLayers.count == 1 && isFirstLayerGroup
        
        // Create a new nested VStack if no root group
        if hasRootGroupLayer,
           let _groupData = childrenLayers.first {
            groupLayer = _groupData
        } else if !hasRootGroupLayer {
            // Add new node as middle-man
            let newGroupNode = CurrentAIPatchBuilderResponseFormat
                .LayerData(node_id: .init(value: .init()),
                           node_name: .init(value: .layer(.group)),
                           children: childrenLayers)
            
            groupLayer = newGroupNode
        } else {
            fatalErrorIfDebug("Unexpected scenario for groups in scroll.")
            throw SwiftUISyntaxError.groupLayerDecodingFailed
        }

        // Enable the appropriate scroll direction(s) based on the detected axis
        let nodeID = groupLayer.node_id.value
        
        switch scrollAxis {
        case .vertical:
            // Enable vertical scrolling only
            groupLayer.custom_layer_input_values += [
                .init(id: nodeID,
                      input: .scrollYEnabled,
                      value: .bool(true)),
                .init(id: nodeID,
                      input: .orientation,
                      value: .orientation(.vertical))
            ]
            
        case .horizontal:
            // Enable horizontal scrolling only
            groupLayer.custom_layer_input_values += [
                .init(id: nodeID,
                      input: .scrollXEnabled,
                      value: .bool(true)),
                .init(id: nodeID,
                      input: .orientation,
                      value: .orientation(.horizontal))
            ]
            
        case .both:
            // Enable both horizontal and vertical scrolling
            groupLayer.custom_layer_input_values.append(contentsOf: [
                .init(id: nodeID, input: .scrollXEnabled, value: .bool(true)),
                .init(id: nodeID, input: .scrollYEnabled, value: .bool(true))
            ])
            
        case .none:
            // No scrolling enabled--make values false in case we change default values later
            groupLayer.custom_layer_input_values.append(contentsOf: [
                .init(id: nodeID, input: .scrollXEnabled, value: .bool(false)),
                .init(id: nodeID, input: .scrollYEnabled, value: .bool(false))
            ])
        }
        
        return groupLayer
    }
    
    // Note: this was written very verbosely, but acceptably
    
    /// Detects the scroll axis from the ScrollView's constructor arguments
    private static func detectScrollAxis(args: [SyntaxViewConstructorArgument]) -> ScrollAxis {
        // First check for array expressions that explicitly list both axes
        for arg in args {
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
        
        for arg in args {
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
        
        return .horizontal
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
