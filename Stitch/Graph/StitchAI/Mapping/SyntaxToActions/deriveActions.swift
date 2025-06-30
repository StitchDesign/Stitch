//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI


extension SyntaxView {

    /// Recursive conversion to **flattened** `[VPLLayerConcept]`
    func recursivelyDeriveActions() -> VPLActions? {
        
        // 1. Map this node
        if var (layer, concepts) = self.name.deriveLayer(
            id: self.id,
            args: self.constructorArguments,
            modifiers: self.modifiers) {
            var childLayers: [VPLCreateNode] = []
            
            // 2. Recurse into children
            for child in children {
                if let childConcepts = child.recursivelyDeriveActions() {
                    // First concept for every child must be its `.layer`
                    if case let .createNode(childLayer) = childConcepts[0] {
                        childLayers.append(childLayer)
                    }
                    concepts.append(contentsOf: childConcepts) // depth-first
                }
            }
            
            let layerWithChildren = VPLCreateNode(id: layer.id,
                                             name: layer.name,
                                             children: childLayers)
            
            // 3. Prepend *this* fully-assembled layer concept
            concepts.insert(.createNode(layerWithChildren), at: 0)
            
            return concepts
        } else {
            return nil
        }
        
    }
}

extension SyntaxView {
    
    func deriveStitchActions() -> VPLActionOrderedSet? {
        if let concepts = recursivelyDeriveActions() {
            return VPLActionOrderedSet(concepts)
        } else {
            return nil
        }
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
