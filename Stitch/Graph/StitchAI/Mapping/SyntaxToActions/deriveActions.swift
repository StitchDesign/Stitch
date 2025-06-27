//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI


// ──────────────────────────────────────────────────────────────
// MARK: - Mapping logic
// ──────────────────────────────────────────────────────────────
extension SyntaxView {
    
    /// Leaf-level mapping for **this** node only
    private func deriveLayer() -> (layer: VPLLayer,
                                   extras: VPLLayerConcepts) {

        // ── Base mapping from SyntaxViewName → Layer ────────────────────────
        var layerType: Layer
        var extras: VPLLayerConcepts = []

        switch self.name {
        case .rectangle:         layerType = .rectangle
        case .circle:            layerType = .oval
        case .text:              layerType = .text
        case .image:             layerType = .image

        case .hStack:
            layerType = .group
            extras.append(
                .layerInputSet(VPLLayerInputSet(id: id,
                                                input: .orientation,
                                                value: .orientation(.horizontal)))
            )

        case .vStack:
            layerType = .group
            extras.append(
                .layerInputSet(VPLLayerInputSet(id: id,
                                                input: .orientation,
                                                value: .orientation(.vertical)))
            )

        case .zStack:
            layerType = .group
            extras.append(
                .layerInputSet(VPLLayerInputSet(id: id,
                                                input: .orientation,
                                                value: .orientation(.none)))
            )

        case .roundedRectangle:
            layerType = .rectangle
            if let arg = constructorArguments.first(where: { $0.label == .cornerRadius }),
               let radius = Double(arg.value) {
                extras.append(
                    .layerInputSet(VPLLayerInputSet(id: id,
                                                    input: .cornerRadius,
                                                    value: .number(radius)))
                )
            }

        default:
            layerType = .hitArea   // safe fallback
        }

        // ── Generic constructor‑argument handling (literals & edges) ─────────
        for arg in constructorArguments {

            // Skip the specialised RoundedRectangle .cornerRadius
            if self.name == .roundedRectangle && arg.label == .cornerRadius { continue }

            guard let port = arg.deriveLayerInputPort(layerType),
                  let portValue = arg.derivePortValue(layerType) else { continue }

            switch arg.syntaxKind {
            case .literal:
                extras.append(
                    .layerInputSet(VPLLayerInputSet(id: id,
                                                    input: port,
                                                    value: portValue))
                )
            case .variable, .expression:
                extras.append(.incomingEdge(VPLIncomingEdge(name: port)))
            }
        }

        // ── Generic modifier handling ────────────────────────────────────────
        for modifier in modifiers {

            guard let port = modifier.name.deriveLayerInputPort(layerType) else { continue }

            // Start with default value for that port
            var portValue = port.getDefaultValue(for: layerType)

            if modifier.arguments.count == 1, let arg = modifier.arguments.first {

                var raw = arg.value
                if let c = Color.fromSystemName(raw) { raw = c.asHexDisplay }
                let input = PortValue.string(.init(raw))

                let coerced = [input].coerce(to: portValue, currentGraphTime: .zero)
                if let first = coerced.first { portValue = first }

            } else {
                for (idx, arg) in modifier.arguments.enumerated() {
                    portValue = portValue.parseInputEdit(
                        fieldValue: .string(.init(arg.value)),
                        fieldIndex: idx
                    )
                }
            }

            extras.append(
                .layerInputSet(VPLLayerInputSet(id: id,
                                                input: port,
                                                value: portValue))
            )
        }

        // Final bare layer (children added later)
        return (VPLLayer(id: id, name: layerType, children: []), extras)
    }
    
    /// Recursive conversion to **flattened** `[VPLLayerConcept]`
    func recursivelyDeriveActions() -> VPLLayerConcepts {
        
        // 1. Map this node
        var (layer, concepts) = deriveLayer()
        var childLayers: [VPLLayer] = []
        
        // 2. Recurse into children
        for child in children {
            let childConcepts = child.recursivelyDeriveActions()
            
            // First concept for every child must be its `.layer`
            if case let .layer(childLayer) = childConcepts[0] {
                childLayers.append(childLayer)
            }
            concepts.append(contentsOf: childConcepts) // depth-first
        }
        
        let layerWithChildren = VPLLayer(id: layer.id,
                                         name: layer.name,
                                         children: childLayers)
        
        // 3. Prepend *this* fully-assembled layer concept
        concepts.insert(.layer(layerWithChildren), at: 0)
        
        return concepts
    }
}

extension SyntaxView {
    
    func deriveStitchActions() -> VPLLayerConceptOrderedSet {
        let concepts = recursivelyDeriveActions()
        return VPLLayerConceptOrderedSet(concepts)
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
