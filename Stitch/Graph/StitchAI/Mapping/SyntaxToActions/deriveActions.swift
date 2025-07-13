//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI

struct SwiftSyntaxActionsResult: Encodable {
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
        // Tracks all silent errors
        var silentErrors = [SwiftUISyntaxError]()
        
        // Recurse into children first (DFS), we might use this data for nested scenarios like ScrollView
        let childResults = try self.children.deriveStitchActions()
        silentErrors += childResults.caughtErrors

        // Map this node
        do {
            let layerDataResult = try self.name.deriveLayerData(
                id: self.id,
                viewConstructor: self.constructor,
                args: self.constructorArguments,
//                args: [],
                modifiers: self.modifiers,
                childrenLayers: childResults.actions)
            
            silentErrors += layerDataResult.silentErrors
            var layerData = layerDataResult.layerData
            
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
                         caughtErrors: silentErrors)
        } catch let error as SwiftUISyntaxError {
            if error.shouldFailSilently {
                log("deriveStitchActions: silent failure for unsupported layer concept: \(error)")
                // Silent error for unsupported layers
                silentErrors.append(error)
                return .init(actions: childResults.actions,
                             caughtErrors: silentErrors)
            } else {
                throw error
            }
        } catch {
            throw error
        }
    }
}

extension SyntaxViewName {
    /// Handles ScrollView-specific logic including axis detection and scroll behavior
    static func createScrollGroupLayer(args: [SyntaxViewArgumentData],
                                       childrenLayers: [CurrentAIPatchBuilderResponseFormat.LayerData]) throws -> CurrentAIPatchBuilderResponseFormat.LayerData {
        // Check the scroll axis from constructor arguments
        // let scrollAxis = Self.detectScrollAxis(args: args)
      
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
                .LayerData(node_id: UUID().description,
                           node_name: .init(value: .layer(.group)),
                           children: childrenLayers)
            
            groupLayer = newGroupNode
        } else {
            fatalErrorIfDebug("Unexpected scenario for groups in scroll.")
            throw SwiftUISyntaxError.groupLayerDecodingFailed
        }
        
        return groupLayer
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
