//
//  VPLToCode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/28/25.
//

import SwiftUI
import StitchSchemaKit
import SwiftSyntax
import SwiftParser


// MARK: - VPL → SwiftUI Constructor (LayerData-only)
// NOTE: This file intentionally avoids any ViewModifier handling for now.

/// Reads explicit values from `LayerData.custom_layer_input_values` and, when
/// missing, falls back to Stitch defaults (for type correctness only).
struct LayerDataConstructorInputs {
    let layer: AIGraphData_V0.Layer
    private let explicit: [LayerInputPort : AIGraphData_V0.PortValue]
    
    public init(layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) {
        if case let .layer(kind) = layerData.node_name.value { self.layer = kind }
        else { self.layer = .group }
        
        var e: [LayerInputPort : AIGraphData_V0.PortValue] = [:]
        for civ in layerData.custom_layer_input_values {
            let port = civ.layer_input_coordinate.input_port_type.value
            if let v = decodePortValueFromCIV(civ, idMap: &idMap) { e[port] = v }
        }
        self.explicit = e
    }
    
    public func value(_ port: LayerInputPort) -> AIGraphData_V0.PortValue {
        explicit[port] ?? port.getDefaultValue(for: layer)
    }
    
    // Typed conveniences (using your existing PortValue helpers)
    public func number(_ p: LayerInputPort) -> Double?               { value(p).getNumber }
    public func bool(_ p: LayerInputPort) -> Bool?                   { value(p).getBool }
    public func string(_ p: LayerInputPort) -> String?               { value(p).getString?.string }
    public func color(_ p: LayerInputPort) -> Color?                 { value(p).getColor }
    public func anchoring(_ p: LayerInputPort) -> Anchoring?         { value(p).getAnchoring }
    public func orientation(_ p: LayerInputPort) -> StitchOrientation? { value(p).getOrientation }
}

/// Decodes a single `CustomLayerInputValue` into a `PortValue` using your
/// existing AI decoding helpers.
func decodePortValueFromCIV(_ customInputValue: AIGraphData_V0.CustomLayerInputValue,
                            idMap: inout [String: UUID]) -> AIGraphData_V0.PortValue? {
    try? AIGraphData_V0.PortValue.decodeFromAI(
        data: customInputValue.value,
        valueType: customInputValue.value_type.value,
        idMap: &idMap
    )
}

/// Produces a `ViewConstructor` for a single `LayerData` node.
/// Only constructor-surface arguments are considered; **no view modifiers**.
func makeConstructorFromLayerData(_ layerData: AIGraphData_V0.LayerData,
                                  idMap: inout [String: UUID]) -> ViewConstructor? {
    let inputs = LayerDataConstructorInputs(layerData: layerData, idMap: &idMap)
    
    switch inputs.layer {
        
        // ───────── Shapes (no-arg) ─────────
    case .oval:
        return .ellipse(NoArgViewConstructor(args: [], layer: .oval))
        
    case .rectangle:
        return .rectangle(RectangleViewConstructor())
        
        // ───────── Text ─────────
    case .text:
        if let s = inputs.string(.text) {
            // Represent the simple `Text("…")` case
            let arg: SyntaxViewModifierArgumentType = .simple(
                SyntaxViewSimpleData(value: s, syntaxKind: .string)
            )
            return .text(.string(arg))
        }
        return nil
        
        // ───────── TextField (placeholder + initial binding preview) ─────────
        //    case .textField:
        //        let title = inputs.string(.placeholderText) ?? ""
        //        let initial = inputs.string(.text) ?? ""
        //        let bindingExpr = ExprSyntax("/* binding */ .constant(\"\(raw: initial)\")")
        //        return .textField(.parameters(title: .literal(title), binding: bindingExpr))
        
        // ───────── Group → H/V/Z stack (alignment/spacing constructor only) ─────────
    case .group:
        let orient = inputs.orientation(.orientation) ?? .vertical
        let spacingNum = inputs.number(.spacing)
        let spacingArg: SyntaxViewModifierArgumentType? = spacingNum.map {
            .simple(SyntaxViewSimpleData(value: String($0), syntaxKind: .float))
        }
        let alignmentArg: SyntaxViewModifierArgumentType? = nil // keep minimal for now
        
        switch orient {
        case .horizontal:
            return .hStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
        case .vertical:
            return .vStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
        case .none:
            return .zStack(.parameters(alignment: alignmentArg))
        case .grid:
            // TODO: .grid orientation becomes SwiftUI LazyVGrid
            return nil
        }
        
        // ───────── Reality primitives (no-arg) ─────────
    case .realityView:
        return .stitchRealityView(.plain)
    case .box:
        return .box(.plain)
    case .cone:
        return .cone(.plain)
    case .cylinder:
        return .cylinder(.plain)
    case .sphere:
        return .sphere(.plain)
        
        // ───────── Not yet handled ─────────
    case .linearGradient, .radialGradient, .angularGradient,
            .textField:
        return nil
        
    default:
        log("makeConstructFromLayerData: COULD NOT TURN LAYER \(inputs.layer) INTO A ViewConstructor")
        return nil
    }
}



