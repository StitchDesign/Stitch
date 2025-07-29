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
func layerDataToStrictSyntaxView(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) -> StrictSyntaxView? {
    // 1. Create the constructor
    guard let constructor = makeConstructorFromLayerData(layerData, idMap: &idMap) else {
        return nil
    }
    
    // 2. Create modifiers from custom_layer_input_values
    let modifiers = createStrictViewModifiersFromLayerData(layerData, idMap: &idMap)
    
    // 3. Convert children recursively
    let children = layerData.children?.compactMap { childLayerData in
        layerDataToStrictSyntaxView(childLayerData, idMap: &idMap)
    } ?? []
    
    // 4. Generate or get UUID for this node
    let nodeId: UUID
    if let existingId = idMap[layerData.node_id] {
        nodeId = existingId
    } else {
        nodeId = UUID()
        idMap[layerData.node_id] = nodeId
    }
    
    return StrictSyntaxView(
        constructor: constructor,
        modifiers: modifiers,
        children: children,
        id: nodeId
    )
}

/// Creates StrictViewModifier array from LayerData custom input values
func createStrictViewModifiersFromLayerData(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) -> [StrictViewModifier] {
    var modifiers: [StrictViewModifier] = []
    
    for customInputValue in layerData.custom_layer_input_values {
        let port = customInputValue.layer_input_coordinate.input_port_type.value
        
        if let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap) {
            // Try to create a typed ViewModifierConstructor first
            if let constructorModifier = makeViewModifierConstructor(from: port, value: portValue) {
                // Convert ViewModifierConstructor to StrictViewModifier
                if let strictModifier = viewModifierConstructorToStrictViewModifier(constructorModifier) {
                    modifiers.append(strictModifier)
                }
            }
            // Note: Non-constructor modifiers are handled in the legacy string generation path
            // and would need additional logic here if we want to support them in StrictSyntaxView
        }
    }
    
    return modifiers
}

/// Converts ViewModifierConstructor to StrictViewModifier
func viewModifierConstructorToStrictViewModifier(_ constructor: ViewModifierConstructor) -> StrictViewModifier? {
    switch constructor {
    case .opacity(let modifier):
        return .opacity(modifier)
    case .scaleEffect(let modifier):
        return .scaleEffect(modifier)
    case .blur(let modifier):
        return .blur(modifier)
    case .zIndex(let modifier):
        return .zIndex(modifier)
    case .cornerRadius(let modifier):
        return .cornerRadius(modifier)
    case .frame(let modifier):
        return .frame(modifier)
    case .foregroundColor(let modifier):
        return .foregroundColor(modifier)
    case .backgroundColor(let modifier):
        return .backgroundColor(modifier)
    case .brightness(let modifier):
        return .brightness(modifier)
    case .contrast(let modifier):
        return .contrast(modifier)
    case .saturation(let modifier):
        return .saturation(modifier)
    case .hueRotation(let modifier):
        return .hueRotation(modifier)
    case .colorInvert(let modifier):
        return .colorInvert(modifier)
    case .position(let modifier):
        return .position(modifier)
    case .offset(let modifier):
        return .offset(modifier)
    case .padding(let modifier):
        return .padding(modifier)
    case .clipped(let modifier):
        return .clipped(modifier)
    }
}

/// Converts a list of LayerData to StrictSyntaxView list
func layerDataListToStrictSyntaxViews(_ layerDataList: [AIGraphData_V0.LayerData], idMap: inout [String: UUID]) -> [StrictSyntaxView] {
    return layerDataList.compactMap { layerData in
        layerDataToStrictSyntaxView(layerData, idMap: &idMap)
    }
}

/// Converts GraphData to a list of StrictSyntaxView (root-level views)
func graphDataToStrictSyntaxViews(_ graphData: AIGraphData_V0.GraphData) -> [StrictSyntaxView] {
    var idMap: [String: UUID] = [:]
    return layerDataListToStrictSyntaxViews(graphData.layer_data_list, idMap: &idMap)
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
        case .hStack, .vStack, .zStack, .lazyHStack, .lazyVStack:
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
    case .backgroundColor(let m):
        return ".backgroundColor(\(renderArg(m.color)))"
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

// MARK: - ViewModifierConstructor (intermediate) mapping & rendering

/// Creates a typed view-modifier constructor from a layer input value, when supported.
func makeViewModifierConstructor(from port: LayerInputPort,
                                 value: AIGraphData_V0.PortValue) -> ViewModifierConstructor? {
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
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: "Color(\(color))", syntaxKind: .string)
            )
            return .foregroundColor(ForegroundColorViewModifier(color: arg))
        }
        return nil
    case .backgroundColor:
        if let color = value.getColor {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: "Color(\(color))", syntaxKind: .string)
            )
            return .backgroundColor(BackgroundColorViewModifier(color: arg))
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
func renderViewModifierConstructor(_ modifier: ViewModifierConstructor) -> String {
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
    case .backgroundColor(let m):
        return ".backgroundColor(\(renderArg(m.color)))"
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

/// Generates all view modifiers for a given LayerData
func generateViewModifiersForLayerData(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) -> [String] {
    var modifiers: [String] = []

    for customInputValue in layerData.custom_layer_input_values {
        let port = customInputValue.layer_input_coordinate.input_port_type.value

        if let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap) {
            // 1) Preferred: go through a typed ViewModifierConstructor if we support it
            if let ctor = makeViewModifierConstructor(from: port, value: portValue) {
                modifiers.append(renderViewModifierConstructor(ctor))
                continue
            }

            // 2) Fallback: legacy direct string mapping for ports not yet modeled
            if let s = layerInputPortToSwiftUIModifier(port: port, value: portValue) {
                modifiers.append(s)
            }
        }
    }

    return modifiers
}

// MARK: - Complete SwiftUI Code Generation (Constructor + Modifiers)

/// Generates complete SwiftUI code for a LayerData including constructor and view modifiers
func generateCompleteSwiftUICode(for layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) -> String? {
    // Generate the base constructor
    guard let constructor = makeConstructorFromLayerData(layerData, idMap: &idMap) else {
        return nil
    }
    
    let baseSwiftUI = constructor.swiftUICallString()
    
    // Generate view modifiers
    let modifiers = generateViewModifiersForLayerData(layerData, idMap: &idMap)
    
    // Combine constructor with modifiers
    if modifiers.isEmpty {
        return baseSwiftUI
    } else {
        let modifierChain = modifiers.joined(separator: "\n    ")
        return baseSwiftUI + "\n    " + modifierChain
    }
}

/// Example usage function showing how to convert a Stitch layer to SwiftUI
func convertStitchLayerToSwiftUI(layerData: AIGraphData_V0.LayerData) -> String? {
    var idMap: [String: UUID] = [:]
    return generateCompleteSwiftUICode(for: layerData, idMap: &idMap)
}
