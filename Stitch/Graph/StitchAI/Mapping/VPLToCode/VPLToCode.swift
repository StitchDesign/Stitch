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
    let explicit: [LayerInputPort : AIGraphData_V0.PortValue]
    
    public init(layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) {
        if case let .layer(kind) = layerData.node_name.value { self.layer = kind }
        else { self.layer = .group }
        
        var explicit: [LayerInputPort : AIGraphData_V0.PortValue] = [:]
        for customInputValue in layerData.custom_layer_input_values {
            let port = customInputValue.layer_input_coordinate.input_port_type.value
            if let v = decodePortValueFromCIV(customInputValue, idMap: &idMap) { explicit[port] = v }
        }
        self.explicit = explicit
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



// MARK: - ViewConstructor → SwiftUI source string (constructors only)
extension ViewConstructor {
    /// Returns a SwiftUI call-site string for this constructor.
    /// NOTE: No modifiers or children are emitted here.
    func swiftUICallString() -> String {
        switch self {
        case .text(let ctor):
            return renderText(ctor)
            
        case .image(let ctor):
            return renderImage(ctor)
            
        case .hStack(let ctor):
            switch ctor {
            case .parameters(let alignment, let spacing):
                let parts = callParts([
                    named("alignment", alignment),
                    named("spacing", spacing)
                ])
                return parts.isEmpty ? "HStack { }" : "HStack(\(parts)) { }"
            }
            
        case .vStack(let ctor):
            switch ctor {
            case .parameters(let alignment, let spacing):
                let parts = callParts([
                    named("alignment", alignment),
                    named("spacing", spacing)
                ])
                return parts.isEmpty ? "VStack { }" : "VStack(\(parts)) { }"
            }
            
        case .zStack(let ctor):
            switch ctor {
            case .parameters(let alignment):
                if let alignment = alignment { return "ZStack(alignment: \(renderArg(alignment))) { }" }
                return "ZStack { }"
            }
            
        case .circle:
            return "Circle()"
            
        case .ellipse:
            return "Ellipse()"
            
        case .rectangle:
            return "Rectangle()"
            
            //        case .roundedRectangle(let ctor):
            //            switch ctor {
            //            case .cornerRadius(let radius):
            //                return "RoundedRectangle(cornerRadius: \(renderArg(radius)))"
            //            }
            //
            //        case .scrollView(let ctor):
            //            switch ctor {
            //            case .axes(let axes):
            //                switch axes {
            //                case .vertical:   return "ScrollView(.vertical) { }"
            //                case .horizontal: return "ScrollView(.horizontal) { }"
            //                case .both:       return "ScrollView([.horizontal, .vertical]) { }"
            //                }
            //            }
            //
            //        case .textField(let ctor):
            //            // Minimal placeholder to avoid binding complexity in this pass
            //            switch ctor {
            //            case .parameters(let title, _):
            //                return "TextField(\(renderTextLiteral(title)), .constant(\"\"))"
            //            default:
            //                return "TextField(/* … */)"
            //            }
            
        case .stitchRealityView:
            return "StitchRealityView()"
        case .box:
            return "Box()"
        case .cone:
            return "Cone()"
        case .cylinder:
            return "Cylinder()"
        case .sphere:
            return "Sphere()"
            
            //        case .angularGradient:
            //            return "AngularGradient(/* not emitted here */)"
            //        case .linearGradient:
            //            return "LinearGradient(/* not emitted here */)"
            //        case .radialGradient:
            //            return "RadialGradient(/* not emitted here */)"
            
        case .spacer, .lazyHStack, .lazyVStack:
            return "NOT YET SUPPORTED"
        }
    }
}

// MARK: - Specific renderers used above
func renderText(_ ctor: TextViewConstructor) -> String {
    switch ctor {
    case .string(let arg):
        return "Text(\(renderArg(arg)))"
    case .verbatim(let arg):
        return "Text(verbatim: \(renderArg(arg)))"
    case .localized(let arg):
        return "Text(\(renderArg(arg)))"
    case .attributed(let arg):
        return "Text(\(renderArg(arg)))"
    }
}

func renderImage(_ ctor: ImageViewConstructor) -> String {
    switch ctor {
    case .sfSymbol(let name):
        return "Image(systemName: \(renderArg(name)))"
    case .asset(let name):
        return "Image(\(renderArg(name)))"
    case .decorative(let name):
        return "Image(decorative: \(renderArg(name)))"
    case .uiImage:
        // Historically tied to async media; keep placeholder
        return "Image(/* async media */)"
    }
}

// MARK: - Argument rendering helpers
func renderArg(_ arg: SyntaxViewModifierArgumentType) -> String {
    switch arg {
    case .simple(let data):
        return renderSimple(data)
    case .memberAccess(let m):
        return m.base.map { "\($0).\(m.property)" } ?? ".\(m.property)"
    case .array(let elements):
        return "[" + elements.map(renderArg).joined(separator: ", ") + "]"
    case .tuple(let fields):
        let inner = fields.map { f in
            let label = f.label ?? "_"
            return "\(label): \(renderArg(f.value))"
        }.joined(separator: ", ")
        return "(\(inner))"
    case .complex(let c):
        // Best-effort for complex types
        let inner = (try? c.arguments.createValuesDict()).map { dict in
            dict.map { "\($0.key): \(renderAnyEncodable($0.value))" }
                .sorted().joined(separator: ", ")
        } ?? ""
        return "\(c.typeName)(\(inner))"
    }
}

func renderSimple(_ s: SyntaxViewSimpleData) -> String {
    switch s.syntaxKind {
    case .string:
        return "\"\(s.value)\""
    case .float:
        return s.value
    case .boolean:
        return s.value.lowercased()
    default:
        return s.value
    }
}

//func renderTextLiteral(_ literal: TextFieldViewConstructor.TextLiteral) -> String {
//    // Render a text literal used in TextField(title:)
//    switch literal {
//    case .literal(let s):
//        return "\"\(s)\""
//    }
//}

func callParts(_ labeled: [String?]) -> String {
    labeled.compactMap { $0 }.joined(separator: ", ")
}

func named(_ label: String, _ arg: SyntaxViewModifierArgumentType?) -> String? {
    guard let a = arg else { return nil }
    return "\(label): \(renderArg(a))"
}

func renderAnyEncodable(_ any: AnyEncodable) -> String {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(any), let s = String(data: data, encoding: .utf8) {
        return s
    }
    return "_"
}
