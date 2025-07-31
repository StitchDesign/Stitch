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
                                  idMap: inout [String: UUID]) -> StrictViewConstructor? {
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
        
        // ───────── Group → H/V/Z stack or ScrollView ─────────
    case .group:
        let orient = inputs.orientation(.orientation) ?? .vertical
        let spacingNum = inputs.number(.spacing)
        let spacingArg: SyntaxViewModifierArgumentType? = spacingNum.map {
            .simple(SyntaxViewSimpleData(value: String($0), syntaxKind: .float))
        }
        let alignmentArg: SyntaxViewModifierArgumentType? = nil // keep minimal for now
        
        // Check if scroll is enabled
        let scrollXEnabled = inputs.bool(.scrollXEnabled) ?? false
        let scrollYEnabled = inputs.bool(.scrollYEnabled) ?? false
        let hasScrolling = scrollXEnabled || scrollYEnabled
        
        if hasScrolling {
            // Generate ScrollView with appropriate axes
            let axesArg: SyntaxViewModifierArgumentType?
            if scrollXEnabled && scrollYEnabled {
                // Both axes enabled → ScrollView([.horizontal, .vertical])
                axesArg = .array([
                    // TODO: should we use `base: "Axis.Set"` ?
                    .memberAccess(SyntaxViewMemberAccess(base: nil, property: "horizontal")),
                    .memberAccess(SyntaxViewMemberAccess(base: nil, property: "vertical"))
                ])
            } else if scrollXEnabled {
                // Only horizontal → ScrollView(.horizontal)
                axesArg = .memberAccess(SyntaxViewMemberAccess(base: nil, property: "horizontal"))
            } else {
                // Only vertical (default) → ScrollView() - no axes parameter needed as vertical is default
                axesArg = nil
            }
            
            return .scrollView(.parameters(axes: axesArg, showsIndicators: nil))
        } else {
            // No scrolling → regular stack based on orientation
            // Extract alignment from layerGroupAlignment for regular stacks too
            let stackAlignmentArg = createAlignmentArg(from: inputs, orientation: orient)
            
            switch orient {
            case .horizontal:
                return .hStack(.parameters(alignment: stackAlignmentArg, spacing: spacingArg))
            case .vertical:
                return .vStack(.parameters(alignment: stackAlignmentArg, spacing: spacingArg))
            case .none:
                return .zStack(.parameters(alignment: stackAlignmentArg))
            case .grid:
                // TODO: .grid orientation becomes SwiftUI LazyVGrid
                return nil
            }
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
        
        // ───────── SF Symbol / Image ─────────
    case .sfSymbol:
        if let symbolName = inputs.string(.sfSymbol) {
            let arg: SyntaxViewModifierArgumentType = .simple(
                SyntaxViewSimpleData(value: symbolName, syntaxKind: .string)
            )
            return .image(.sfSymbol(name: arg))
        }
        return nil
        
        // ───────── Not yet handled ─────────
    case .linearGradient, .radialGradient, .angularGradient,
            .textField:
        return nil
        
    default:
        log("makeConstructFromLayerData: COULD NOT TURN LAYER \(inputs.layer) INTO A ViewConstructor")
        return nil
    }
}

// MARK: - LayerData → StrictSyntaxView Conversion

/// Converts LayerData to StrictSyntaxView with constructor, modifiers, and children
func layerDataToStrictSyntaxView(_ layerData: AIGraphData_V0.LayerData,
                                 idMap: inout [String: UUID]) throws -> StrictSyntaxView? {
    // 1. Create the constructor
    guard let constructor = makeConstructorFromLayerData(layerData, idMap: &idMap) else {
        return nil
    }
    
    // 2. Create modifiers from custom_layer_input_values
    let modifiers = try createStrictViewModifiersFromLayerData(layerData, idMap: &idMap)
    
    // 3. Convert children recursively
    let children = try layerData.children?.compactMap { childLayerData in
        try layerDataToStrictSyntaxView(childLayerData, idMap: &idMap)
    } ?? []
    
    // 4. Generate or get UUID for this node
    let nodeId: UUID
    if let existingId = idMap[layerData.node_id] {
        nodeId = existingId
    } else {
        nodeId = UUID()
        idMap[layerData.node_id] = nodeId
    }
    
    // 5. Handle ScrollView + Stack nesting for scroll-enabled groups
    if case .scrollView = constructor {
        // Create the inner stack based on the group's orientation
        let innerStackConstructor = createInnerStackConstructor(layerData, idMap: &idMap)
        let innerStackView = StrictSyntaxView(
            constructor: innerStackConstructor,
            modifiers: [], // Stack doesn't get the modifiers, ScrollView does
            children: children, // Original children go into the stack
            id: UUID()
        )
        
        // ScrollView contains the stack as its only child
        return StrictSyntaxView(
            constructor: constructor,
            modifiers: modifiers,
            children: [innerStackView], // ScrollView wraps the stack
            id: nodeId
        )
    }
    
    return StrictSyntaxView(
        constructor: constructor,
        modifiers: modifiers,
        children: children,
        id: nodeId
    )
}

/// Creates the inner stack constructor for a ScrollView based on the group's orientation
func createInnerStackConstructor(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) -> StrictViewConstructor {
    let inputs = LayerDataConstructorInputs(layerData: layerData, idMap: &idMap)
    let orient = inputs.orientation(.orientation) ?? .vertical
    let spacingNum = inputs.number(.spacing)
    let spacingArg: SyntaxViewModifierArgumentType? = spacingNum.map {
        .simple(SyntaxViewSimpleData(value: String($0), syntaxKind: .float))
    }
    
    // Extract alignment from layerGroupAlignment
    let alignmentArg = createAlignmentArg(from: inputs, orientation: orient)
    
    switch orient {
    case .horizontal:
        return .hStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
    case .vertical:
        return .vStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
    case .none:
        return .zStack(.parameters(alignment: alignmentArg))
    case .grid:
        // Fallback to VStack for grid orientation
        return .vStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
    }
}

/// Creates alignment argument from LayerData inputs based on stack orientation
func createAlignmentArg(from inputs: LayerDataConstructorInputs, orientation: StitchOrientation) -> SyntaxViewModifierArgumentType? {
    guard let anchoring = inputs.anchoring(.layerGroupAlignment) else {
        return nil // Use SwiftUI default alignment
    }
    
    // Convert Stitch Anchoring to SwiftUI alignment based on stack orientation
    let alignmentProperty: String?
    
    switch orientation {
    case .horizontal:
        // HStack uses VerticalAlignment
        switch anchoring {
        case .topCenter, .topLeft, .topRight:
            alignmentProperty = "top"
        case .centerCenter, .centerLeft, .centerRight:
            alignmentProperty = "center"
        case .bottomCenter, .bottomLeft, .bottomRight:
            alignmentProperty = "bottom"
            
        // Note: technically, Stitch Anchoring is a (0,0), which is many more values than SwiftUI Alignment
        default:
            alignmentProperty = "center"
        }
        
    case .vertical:
        // VStack uses HorizontalAlignment
        switch anchoring {
        case .centerLeft, .topLeft, .bottomLeft:
            alignmentProperty = "leading"
        case .centerCenter, .topCenter, .bottomCenter:
            alignmentProperty = "center"
        case .centerRight, .topRight, .bottomRight:
            alignmentProperty = "trailing"
        default:
            alignmentProperty = "center"
        }
        
    case .none:
        // ZStack uses Alignment (both horizontal and vertical)
        switch anchoring {
        case .topLeft:
            alignmentProperty = "topLeading"
        case .topCenter:
            alignmentProperty = "top"
        case .topRight:
            alignmentProperty = "topTrailing"
        case .centerLeft:
            alignmentProperty = "leading"
        case .centerCenter:
            alignmentProperty = "center"
        case .centerRight:
            alignmentProperty = "trailing"
        case .bottomLeft:
            alignmentProperty = "bottomLeading"
        case .bottomCenter:
            alignmentProperty = "bottom"
        case .bottomRight:
            alignmentProperty = "bottomTrailing"
        default:
            alignmentProperty = "center"
        }
        
    case .grid:
        // Grid uses HorizontalAlignment like VStack
        switch anchoring {
        case .centerLeft, .topLeft, .bottomLeft:
            alignmentProperty = "leading"
        case .centerCenter, .topCenter, .bottomCenter:
            alignmentProperty = "center"
        case .centerRight, .topRight, .bottomRight:
            alignmentProperty = "trailing"
        default:
            alignmentProperty = "center"
        }
    }
    
    guard let property = alignmentProperty else { return nil }
    
    return .memberAccess(SyntaxViewMemberAccess(base: nil, property: property))
}

/// Creates StrictViewModifier array from LayerData custom input values
func createStrictViewModifiersFromLayerData(_ layerData: AIGraphData_V0.LayerData,
                                            idMap: inout [String: UUID]) throws -> [StrictViewModifier] {
    var modifiers: [StrictViewModifier] = []
    
    // Extract layer type from layerData
    let layerType: AIGraphData_V0.Layer
    switch layerData.node_name.value {
    case .layer(let x):
        layerType = x
    case .patch(let x):
        throw SwiftUISyntaxError.unexpectedPatch(x)
        layerType = .group // BAD
    }
    
    for customInputValue in layerData.custom_layer_input_values {
        let port = customInputValue.layer_input_coordinate.input_port_type.value
        
        if let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap) {
            // Try to create a typed ViewModifierConstructor first
            if let constructorModifier = makeViewModifierConstructor(from: port, value: portValue, layerType: layerType) {
                modifiers.append(constructorModifier)
            }
            // Note: Non-constructor modifiers are handled in the legacy string generation path
            // and would need additional logic here if we want to support them in StrictSyntaxView
        }
    }
    
    return modifiers
}


/// Converts a list of LayerData to StrictSyntaxView list
func layerDataListToStrictSyntaxViews(_ layerDataList: [AIGraphData_V0.LayerData], idMap: inout [String: UUID]) throws -> [StrictSyntaxView] {
    return try layerDataList.compactMap { layerData in
        try layerDataToStrictSyntaxView(layerData, idMap: &idMap)
    }
}

/// Converts GraphData to a list of StrictSyntaxView (root-level views)
func graphDataToStrictSyntaxViews(_ graphData: AIGraphData_V0.GraphData) throws -> [StrictSyntaxView] {
    var idMap: [String: UUID] = [:]
    return try layerDataListToStrictSyntaxViews(graphData.layer_data_list, idMap: &idMap)
}

// MARK: - StrictSyntaxView → SwiftUI Code Generation

extension StrictSyntaxView {
    /// Generates complete SwiftUI code string for this view including modifiers and children
    func toSwiftUICode() -> String {
        let constructorString = constructor.swiftUICallString()
        
        // Handle children for container views
        let viewWithChildren = constructorString + generateChildrenCode()
        
        // Apply modifiers after the complete view (including children)
        let modifiersString = modifiers.map { modifier in
            renderStrictViewModifier(modifier)
        }.joined()
        
        return viewWithChildren + modifiersString
    }
    
    private func generateChildrenCode() -> String {
        guard !children.isEmpty else { return "" }
        
        // Check if this is a container view that needs children
        switch constructor {
        case .hStack, .vStack, .zStack, .scrollView, .lazyHStack, .lazyVStack:
            let childrenCode = children.map { child in
                // Add proper indentation for each child
                child.toSwiftUICode().components(separatedBy: "\n")
                    .map { line in line.isEmpty ? "" : "    \(line)" }
                    .joined(separator: "\n")
            }.joined(separator: "\n")
            return " {\n\(childrenCode)\n}"
        default:
            // Non-container views - children are ignored or handled differently
            return ""
        }
    }
}

/// Renders a StrictViewModifier to SwiftUI modifier string
func renderStrictViewModifier(_ modifier: StrictViewModifier) -> String {
    switch modifier {
    case .opacity(let m):
        return ".opacity(\(renderArg(m.value)))"
    case .scaleEffect(let m):
        switch m {
        case .uniform(let scale, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(scale))\(anchorPart))"
        case .xy(let x, let y, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(x: \(renderArg(x)), y: \(renderArg(y))\(anchorPart))"
        case .size(let size, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(size))\(anchorPart))"
        }
    case .blur(let m):
        return ".blur(radius: \(renderArg(m.radius)))"
    case .zIndex(let m):
        return ".zIndex(\(renderArg(m.value)))"
    case .cornerRadius(let m):
        return ".cornerRadius(\(renderArg(m.radius)))"
    case .frame(let m):
        var parts: [String] = []
        if let width = m.width {
            parts.append("width: \(renderArg(width))")
        }
        if let height = m.height {
            parts.append("height: \(renderArg(height))")
        }
        // Only generate .frame() if we have at least one parameter
        guard !parts.isEmpty else { return "" }
        return ".frame(\(parts.joined(separator: ", ")))"
    case .foregroundColor(let m):
        return ".foregroundColor(\(renderArg(m.color)))"
    case .fill(let m):
        return ".fill(\(renderArg(m.color)))"
    case .brightness(let m):
        return ".brightness(\(renderArg(m.value)))"
    case .contrast(let m):
        return ".contrast(\(renderArg(m.value)))"
    case .saturation(let m):
        return ".saturation(\(renderArg(m.value)))"
    case .hueRotation(let m):
        return ".hueRotation(\(renderArg(m.angle)))"
    case .colorInvert(_):
        return ".colorInvert()"
    case .position(let m):
        return ".position(x: \(renderArg(m.x)), y: \(renderArg(m.y)))"
    case .offset(let m):
        return ".offset(x: \(renderArg(m.x)), y: \(renderArg(m.y)))"
    case .padding(let m):
        if let length = m.length {
            return ".padding(\(renderArg(length)))"
        } else {
            return ".padding()"
        }
    case .clipped(_):
        return ".clipped()"
    }
}

// MARK: - ViewConstructor → SwiftUI source string (constructors only)
extension StrictViewConstructor {
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
                return parts.isEmpty ? "HStack" : "HStack(\(parts))"
            }
            
        case .vStack(let ctor):
            switch ctor {
            case .parameters(let alignment, let spacing):
                let parts = callParts([
                    named("alignment", alignment),
                    named("spacing", spacing)
                ])
                return parts.isEmpty ? "VStack" : "VStack(\(parts))"
            }
            
        case .zStack(let ctor):
            switch ctor {
            case .parameters(let alignment):
                if let alignment = alignment { return "ZStack(alignment: \(renderArg(alignment)))" }
                return "ZStack"
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
        case .scrollView(let ctor):
            switch ctor {
            case .parameters(let axes, let showsIndicators):
                let parts = callParts([
                    unnamed(axes),
                    named("showsIndicators", showsIndicators)
                ])
                return parts.isEmpty ? "ScrollView" : "ScrollView(\(parts))"
            }
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

func unnamed(_ arg: SyntaxViewModifierArgumentType?) -> String? {
    guard let a = arg else { return nil }
    return renderArg(a)
}

func renderAnyEncodable(_ any: AnyEncodable) -> String {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(any), let s = String(data: data, encoding: .utf8) {
        return s
    }
    return "_"
}

// TODO: this is probably redundant vs. other ways of parsing semantic colors
/// Creates proper SwiftUI color syntax for a Stitch color value
func createColorArgument(_ color: Color) -> SyntaxViewModifierArgumentType {
    // Check if this is a semantic color (e.g., Color.blue, Color.red)
    switch color {
    case .black:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "black"))
    case .blue:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "blue"))
    case .brown:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "brown"))
    case .clear:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "clear"))
    case .cyan:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "cyan"))
    case .gray:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "gray"))
    case .green:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "green"))
    case .indigo:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "indigo"))
    case .mint:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "mint"))
    case .orange:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "orange"))
    case .pink:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "pink"))
    case .purple:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "purple"))
    case .red:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "red"))
    case .teal:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "teal"))
    case .white:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "white"))
    case .yellow:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "yellow"))
    default:
        // For custom colors, use Color(...) initializer with RGBA values
        let rgba = color.asRGBA
        let redString = String(format: "%.3f", rgba.red)
        let greenString = String(format: "%.3f", rgba.green)
        let blueString = String(format: "%.3f", rgba.blue)
        let alphaString = String(format: "%.3f", rgba.alpha)
                
        return .complex(SyntaxViewModifierComplexType(
            typeName: "Color",
            arguments: [
                .init(label: "red", value: .simple(SyntaxViewSimpleData(value: redString, syntaxKind: .float))),
                .init(label: "green", value: .simple(SyntaxViewSimpleData(value: greenString, syntaxKind: .float))),
                .init(label: "blue", value: .simple(SyntaxViewSimpleData(value: blueString, syntaxKind: .float))),
                .init(label: "opacity", value: .simple(SyntaxViewSimpleData(value: alphaString, syntaxKind: .float)))
            ]
        ))
    }
}

// MARK: - ViewModifierConstructor (intermediate) mapping & rendering

/// Creates a typed view-modifier constructor from a layer input value, when supported.
func makeViewModifierConstructor(from port: LayerInputPort,
                                 value: AIGraphData_V0.PortValue,
                                 layerType: AIGraphData_V0.Layer) -> StrictViewModifier? {
    switch port {
    case .opacity:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .opacity(OpacityViewModifier(value: arg))
        }
        return nil
    case .scale:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .scaleEffect(.uniform(scale: arg, anchor: nil))
        }
        return nil
    case .blur, .blurRadius:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .blur(BlurViewModifier(radius: arg))
        }
        return nil
    case .zIndex:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .zIndex(ZIndexViewModifier(value: arg))
        }
        return nil
    case .cornerRadius:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .cornerRadius(CornerRadiusViewModifier(radius: arg))
        }
        return nil
    case .size:
        if let size = value.getSize {
            var width: SyntaxViewModifierArgumentType?
            var height: SyntaxViewModifierArgumentType?
            
            // Convert LayerDimension to SyntaxViewModifierArgumentType
            if case .number(let widthValue) = size.width {
                width = .simple(SyntaxViewSimpleData(value: widthValue.description,
                                                     syntaxKind: .float))
            }
            
            if case .number(let heightValue) = size.height {
                height = .simple(SyntaxViewSimpleData(value: heightValue.description,
                                                      syntaxKind: .float))
            }
            
            // Only create the modifier if we have at least one dimension
            if width != nil || height != nil {
                return .frame(FrameViewModifier(width: width, height: height))
            }
        }
        return nil
    case .color:
        if let color = value.getColor {
            let arg = createColorArgument(color)
            // Choose modifier based on layer type
            switch layerType {
            case .rectangle, .oval, .shape:
                // Shape layers use .fill()
                return .fill(FillViewModifier(color: arg))
            case .text, .textField:
                // Text layers use .foregroundColor()
                return .foregroundColor(ForegroundColorViewModifier(color: arg))
            default:
                // Default to .foregroundColor() for other layer types
                return .foregroundColor(ForegroundColorViewModifier(color: arg))
            }
        }
        return nil
    case .brightness:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .brightness(BrightnessViewModifier(value: arg))
        }
        return nil
    case .contrast:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .contrast(ContrastViewModifier(value: arg))
        }
        return nil
    case .saturation:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .float)
            )
            return .saturation(SaturationViewModifier(value: arg))
        }
        return nil
    case .hueRotation:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: ".degrees(\(number))", syntaxKind: .string)
            )
            return .hueRotation(HueRotationViewModifier(angle: arg))
        }
        return nil
    case .colorInvert:
        if let bool = value.getBool, bool {
            return .colorInvert(ColorInvertViewModifier())
        }
        return nil
    case .position:
        if let position = value.getPosition {
            let xArg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: position.x.description, syntaxKind: .float)
            )
            let yArg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: position.y.description, syntaxKind: .float)
            )
            return .position(PositionViewModifier(x: xArg, y: yArg))
        }
        return nil
    case .offsetInGroup:
        if let position = value.getPosition {
            let xArg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: position.x.description, syntaxKind: .float)
            )
            let yArg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: position.y.description, syntaxKind: .float)
            )
            return .offset(OffsetViewModifier(x: xArg, y: yArg))
        }
        return nil
    case .padding:
        if let padding = value.getPadding {
            // For now, handle uniform padding only
            if padding.top == padding.right && padding.right == padding.bottom && padding.bottom == padding.left {
                let arg = SyntaxViewModifierArgumentType.simple(
                    SyntaxViewSimpleData(value: padding.top.description, syntaxKind: .float)
                )
                return .padding(PaddingViewModifier(edges: nil, length: arg))
            }
        }
        return nil
    case .isClipped:
        if let bool = value.getBool, bool {
            return .clipped(ClippedViewModifier())
        }
        return nil
    default:
        return nil
    }
}

/// Renders a typed view-modifier constructor back into SwiftUI source code.
func renderViewModifierConstructor(_ modifier: StrictViewModifier) -> String {
    switch modifier {
    case .opacity(let m):
        return ".opacity(\(renderArg(m.value)))"
    case .scaleEffect(let m):
        switch m {
        case .uniform(let scale, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(scale))\(anchorPart))"
        case .xy(let x, let y, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(x: \(renderArg(x)), y: \(renderArg(y))\(anchorPart))"
        case .size(let size, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(size))\(anchorPart))"
        }
    case .blur(let m):
        return ".blur(radius: \(renderArg(m.radius)))"
    case .zIndex(let m):
        return ".zIndex(\(renderArg(m.value)))"
    case .cornerRadius(let m):
        return ".cornerRadius(\(renderArg(m.radius)))"
    case .frame(let m):
        var parts: [String] = []
        if let width = m.width {
            parts.append("width: \(renderArg(width))")
        }
        if let height = m.height {
            parts.append("height: \(renderArg(height))")
        }
        // Only generate .frame() if we have at least one parameter
        guard !parts.isEmpty else { return "" }
        return ".frame(\(parts.joined(separator: ", ")))"
    case .foregroundColor(let m):
        return ".foregroundColor(\(renderArg(m.color)))"
    case .fill(let m):
        return ".fill(\(renderArg(m.color)))"
    case .brightness(let m):
        return ".brightness(\(renderArg(m.value)))"
    case .contrast(let m):
        return ".contrast(\(renderArg(m.value)))"
    case .saturation(let m):
        return ".saturation(\(renderArg(m.value)))"
    case .hueRotation(let m):
        return ".hueRotation(\(renderArg(m.angle)))"
    case .colorInvert(_):
        return ".colorInvert()"
    case .position(let m):
        return ".position(x: \(renderArg(m.x)), y: \(renderArg(m.y)))"
    case .offset(let m):
        return ".offset(x: \(renderArg(m.x)), y: \(renderArg(m.y)))"
    case .padding(let m):
        if let length = m.length {
            return ".padding(\(renderArg(length)))"
        } else {
            return ".padding()"
        }
    case .clipped(_):
        return ".clipped()"
    }
}

// MARK: - LayerInputPort → SwiftUI View Modifier Mapping

/// Maps a LayerInputPort and its PortValue to a SwiftUI view modifier string.
/// Returns nil if the LayerInputPort doesn't correspond to a view modifier.
func layerInputPortToSwiftUIModifier(port: LayerInputPort, value: AIGraphData_V0.PortValue) -> String? {
    switch port {
    // Simple single-argument modifiers
    case .opacity:
        // Handled via intermediate ViewModifierConstructor (.opacity) pathway
        return nil
    case .scale:
        // Handled via intermediate ViewModifierConstructor (.scaleEffect) pathway
        return nil
    case .zIndex:
        // Handled via intermediate ViewModifierConstructor (.zIndex) pathway
        return nil
        
    case .blur, .blurRadius:
        // Handled via intermediate ViewModifierConstructor (.blur) pathway
        return nil
        
    case .cornerRadius:
        // Handled via intermediate ViewModifierConstructor (.cornerRadius) pathway
        return nil
        
    case .brightness:
        // Handled via intermediate ViewModifierConstructor (.brightness) pathway
        return nil
        
    case .contrast:
        // Handled via intermediate ViewModifierConstructor (.contrast) pathway
        return nil
        
    case .saturation:
        // Handled via intermediate ViewModifierConstructor (.saturation) pathway
        return nil
        
    case .hueRotation:
        // Handled via intermediate ViewModifierConstructor (.hueRotation) pathway
        return nil
        
    // Color modifiers - handled via ViewModifierConstructor pathway
    case .color:
        // Handled via intermediate ViewModifierConstructor (.foregroundColor) pathway
        return nil
        
    case .backgroundColor:
        // Handled via intermediate ViewModifierConstructor (.backgroundColor) pathway
        return nil
        
    // Boolean modifiers
    case .colorInvert:
        // Handled via intermediate ViewModifierConstructor (.colorInvert) pathway
        return nil
        
    case .isClipped, .clipped:
        // Handled via intermediate ViewModifierConstructor (.clipped) pathway
        return nil
        
//    case .disabled:
//        if let bool = value.getBool {
//            return ".disabled(\(bool))"
//        }
        
    // Complex modifiers - handled via ViewModifierConstructor pathway
    case .offsetInGroup:
        // Handled via intermediate ViewModifierConstructor (.offset) pathway
        return nil
        
    case .size:
        // Handled via intermediate ViewModifierConstructor (.frame) pathway
        return nil
        
    case .padding:
        // Handled via intermediate ViewModifierConstructor (.padding) pathway
        return nil
        
    case .position:
        // Handled via intermediate ViewModifierConstructor (.position) pathway
        return nil
        
    // TODO: this is not quite correct; `.text` needs to be
    // Modifiers that don't have direct SwiftUI equivalents or are handled at constructor level
    case .anchoring, .orientation, .text, .sfSymbol, .image, .video, .spacing, .layerGroupAlignment:
        return nil
        
    default:
        return nil
    }
    
    return nil
}

// TODO: use the existing color helpers
/// Renders a Color value as SwiftUI code
func renderColor(_ color: Color) -> String {
    // Convert SwiftUI Color to a string representation
    if color == .red { return "Color.red" }
    if color == .blue { return "Color.blue" }
    if color == .green { return "Color.green" }
    if color == .yellow { return "Color.yellow" }
    if color == .orange { return "Color.orange" }
    if color == .purple { return "Color.purple" }
    if color == .pink { return "Color.pink" }
    if color == .black { return "Color.black" }
    if color == .white { return "Color.white" }
    if color == .gray { return "Color.gray" }
    if color == .clear { return "Color.clear" }
    
    // For custom colors, fall back to a generic representation
    return "Color(/* custom color */)"
}

/// Generates all view modifiers for a given LayerData as strings
/// This is a convenience wrapper around createStrictViewModifiersFromLayerData
func generateViewModifiersForLayerData(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) throws -> [String] {
    // Reuse the typed modifier creation logic
    let typedModifiers = try createStrictViewModifiersFromLayerData(layerData, idMap: &idMap)
    
    // Convert typed modifiers to strings
    var stringModifiers = typedModifiers.map { renderViewModifierConstructor($0) }
    
    // Handle any remaining ports that don't have typed modifiers yet (legacy fallback)
    let handledPorts = Set(typedModifiers.compactMap { modifier -> LayerInputPort? in
        // Extract the port type from each typed modifier for comparison
        switch modifier {
        case .opacity: return .opacity
        case .scaleEffect: return .scale
        case .blur: return .blur
        case .zIndex: return .zIndex
        case .cornerRadius: return .cornerRadius
        case .frame: return .size
        case .foregroundColor, .fill: return .color
        case .brightness: return .brightness
        case .contrast: return .contrast
        case .saturation: return .saturation
        case .hueRotation: return .hueRotation
        case .colorInvert: return .colorInvert
        case .position: return .position
        case .offset: return .offsetInGroup
        case .padding: return .padding
        case .clipped: return .isClipped
        }
    })
    
    // Add legacy string modifiers for unhandled ports
    for customInputValue in layerData.custom_layer_input_values {
        let port = customInputValue.layer_input_coordinate.input_port_type.value
        
        if !handledPorts.contains(port),
           let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap),
           let s = layerInputPortToSwiftUIModifier(port: port, value: portValue) {
            stringModifiers.append(s)
        }
    }
    
    return stringModifiers
}

// MARK: - Complete SwiftUI Code Generation (Constructor + Modifiers)

/// Generates complete SwiftUI code for a LayerData including constructor and view modifiers
func generateCompleteSwiftUICode(for layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) throws -> String? {
    // Generate the base constructor
    guard let constructor = makeConstructorFromLayerData(layerData, idMap: &idMap) else {
        return nil
    }
    
    let baseSwiftUI = constructor.swiftUICallString()
    
    // Generate view modifiers
    let modifiers = try generateViewModifiersForLayerData(layerData, idMap: &idMap)
    
    // Combine constructor with modifiers
    if modifiers.isEmpty {
        return baseSwiftUI
    } else {
        let modifierChain = modifiers.joined(separator: "\n    ")
        return baseSwiftUI + "\n    " + modifierChain
    }
}

/// Example usage function showing how to convert a Stitch layer to SwiftUI
func convertStitchLayerToSwiftUI(layerData: AIGraphData_V0.LayerData) throws -> String? {
    var idMap: [String: UUID] = [:]
    return try generateCompleteSwiftUICode(for: layerData, idMap: &idMap)
}
