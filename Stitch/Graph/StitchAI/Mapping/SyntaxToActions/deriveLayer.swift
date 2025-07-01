//
//  deriveLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI

struct SyntaxViewLayerData {
    var node: CurrentAIPatchBuilderResponseFormat.LayerNode
    let customLayerInputValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]
}

extension SyntaxViewName {
        
    
    /// Leaf-level mapping for **this** node only
    func deriveLayer(id: UUID,
                     args: [SyntaxViewConstructorArgument],
                     modifiers: [SyntaxViewModifier]) throws -> SyntaxViewLayerData {
        
        // ── Base mapping from SyntaxViewName → Layer ────────────────────────
        var layerType: CurrentStep.Layer
        var customValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] = []

        switch self {
        case .rectangle:         layerType = .rectangle
            
        // Note: Swift Circle is a little bit different
        case .circle, .ellipse:  layerType = .oval
        
        // SwiftUI Text view has different arg-constructors, but those do not change the Layer we return
        case .text: layerType = .text
            
        // SwiftUI TextField view has different arg-constructors, but those do not change the Layer we return
        case .textField: layerType = .textField
            
        case .image:
            switch args.first?.label {
            case .systemName: layerType = .sfSymbol
            default: layerType = .image
            }
            
        case .map: layerType = .map
            
            // Revisit these
        case .videoPlayer: layerType = .video
        case .model3D: layerType = .model3D
            
        case .linearGradient: layerType = .linearGradient
        case .radialGradient: layerType = .radialGradient
        case .angularGradient: layerType = .angularGradient
        case .material: layerType = .material
            
            // TODO: JUNE 24: what actually is SwiftUI sketch ?
        case .canvas: layerType = .canvasSketch
            
        case .secureField:
            // TODO: JUNE 24: ought to return `(Layer.textField, LayerInputPort.keyboardType, UIKeyboardType.password)` ? ... so a SwiftUI View can correspond to more than just a Layer ?
            layerType = .textField
            
        case .capsule:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .path:
            throw SwiftUISyntaxError.unsupportedLayer(self) // Canvas sketch ?
        case .color:
            throw SwiftUISyntaxError.unsupportedLayer(self) // both Layer.hitArea AND Layer.colorFill
            
        case .label:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .asyncImage:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .symbolEffect:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .group:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .spacer:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .divider:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .geometryReader:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .alignmentGuide:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .scrollView:
            throw SwiftUISyntaxError.unsupportedLayer(self) // TODO: support
        case .list:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .table:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .outlineGroup:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .forEach:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .navigationStack:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .navigationSplit:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .navigationLink:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .tabView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .form:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .section:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .button:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .toggle:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .slider:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .stepper:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .picker:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .datePicker:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .gauge:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .progressView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .link:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .timelineView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .anyView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .preview:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .timelineSchedule:
            throw SwiftUISyntaxError.unsupportedLayer(self)
            
            
        // TODO: JUNE 26: handle incoming edges as well
        // Views that create a set-input as well
            
        case .hStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.horizontal))
            )

        case .vStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.vertical))
            )

        case .zStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.none))
            )

        case .roundedRectangle:
            layerType = .rectangle
            if let arg = args.first(where: { $0.label == .cornerRadius }),
               let radius = Double(arg.value) {
                customValues.append(
                    .init(id: id,
                          input: .cornerRadius,
                          value: .number(radius))
                )
            }

        default:
            layerType = .hitArea   // safe fallback
        }

        // ── Generic constructor‑argument handling (literals & edges) ─────────
        for arg in args {

            // TODO: why are we skipping these ?
            // Skip the specialised RoundedRectangle .cornerRadius
            if self == .roundedRectangle && arg.label == .cornerRadius { continue }

            guard let port = arg.deriveLayerInputPort(layerType),
                  let portValue = arg.derivePortValue(layerType) else { continue }

            switch arg.syntaxKind {
            case .literal:
                customValues.append(
                    .init(id: id,
                          input: port,
                          value: portValue)
                )
            case .variable, .expression:
                // Skip variables for edges, using AI instead
                continue
//                extras.append(.createEdge(VPLCreateEdge(name: port)))
            }
        }

        // ── Generic modifier handling ────────────────────────────────────────
        for modifier in modifiers {

            guard let port = modifier.name.deriveLayerInputPort(layerType) else {
                continue
            }
            
            let migratedPort = try port.convert(to: LayerInputPort.self)
            let migratedLayerType = try layerType.convert(to: Layer.self)

            // Start with default value for that port
            var portValue = migratedPort.getDefaultValue(for: migratedLayerType)

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
            
            // "Downgrade" PortValue back to supported type for the AI
            let downgradedValue = try portValue.convert(to: CurrentStep.PortValue.self)

            customValues.append(
                .init(id: id,
                      input: port,
                      value: downgradedValue)
            )
        }

        // Final bare layer (children added later)
        let layeNode = CurrentAIPatchBuilderResponseFormat
            .LayerNode(node_id: .init(value: id),
                       node_name: .init(value: .layer(layerType)))
        return .init(node: layeNode,
                     customLayerInputValues: customValues)
    }
    
}
