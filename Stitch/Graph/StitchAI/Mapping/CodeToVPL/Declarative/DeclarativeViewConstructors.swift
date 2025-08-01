//
//  SyntaxViewConstructors.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/9/25.
//

import Foundation
import SwiftUI
import UIKit
import StitchSchemaKit
import SwiftSyntax
import SwiftParser



protocol FromSwiftUIViewToStitch: Encodable {
    associatedtype T
    
    // nil if ViewConstructor could not be turned into Stitch concepts
    //    var toStitch: (
    //        Layer?, // nil e.g. for ScrollView, which contributes custom-values but not own layer
    //        [ValueOrEdge]
    //    )? { get }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> T?
    
    // TODO: this property is incorrect -- some SwiftUI views like ScrollView may not become a Layer
    var layer: AIGraphData_V0.Layer { get }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue]
}


// TODO: can we just the `FromSwiftUIViewToStitch` protocol instead? But tricky, since `FromSwiftUIViewToStitch` has an associated i.e. generic type, which would bubble up elsewhere.
enum StrictViewConstructor: Equatable, Encodable {
    case text(TextViewConstructor)
    case image(ImageViewConstructor)
    case hStack(HStackViewConstructor)
    case vStack(VStackViewConstructor)
    case zStack(ZStackViewConstructor)
    case circle(CircleViewConstructor)
    case ellipse(NoArgViewConstructor)
    case rectangle(RectangleViewConstructor)
    
    case scrollView(ScrollViewViewConstructor)
    
    // Augmented Reality
    case stitchRealityView(StitchRealityViewConstructor)
    case box(BoxViewConstructor)
    case cone(ConeViewConstructor)
    case cylinder(CylinderViewConstructor)
    case sphere(SphereViewConstructor)
    
    case spacer(SpacerViewConstructor)
    
    // New: Lazy stacks
    case lazyHStack(LazyHStackViewConstructor)
    case lazyVStack(LazyVStackViewConstructor)
    
    var value: any FromSwiftUIViewToStitch {
        switch self {
        case .text(let c):             return c
        case .image(let c):            return c
        case .hStack(let c):           return c
        case .vStack(let c):           return c
        case .zStack(let c):           return c
        case .circle(let c):           return c
        case .ellipse(let c):          return c
        case .rectangle(let c):        return c
        case .scrollView(let c):        return c
        case .stitchRealityView(let c): return c
        case .box(let c):               return c
        case .cone(let c):              return c
        case .cylinder(let c):          return c
        case .sphere(let c):            return c
        case .spacer(let c):            return c
        case .lazyHStack(let c):        return c
        case .lazyVStack(let c):        return c
        }
    }
}


/// Runs every `…ViewConstructor.from(node)` helper once. If an enum is
/// returned, attach it to the *current* SyntaxView.
func createKnownViewConstructor(from node: FunctionCallExprSyntax,
                                               arguments: [SyntaxViewArgumentData]) -> StrictViewConstructor? {
    
    guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
          let viewName = SyntaxViewName(rawValue: name) else {
        return nil
    }
    
    switch viewName {
    case .text:
        return TextViewConstructor.from(arguments,
                                        viewName: viewName)
        .map { .text($0) }
    case .image:
        return ImageViewConstructor.from(arguments,
                                         viewName: viewName)
        .map { .image($0) }
    case .hStack:
        return HStackViewConstructor.from(arguments,
                                          viewName: viewName)
        .map { .hStack($0) }
    case .vStack:
        return VStackViewConstructor.from(arguments,
                                          viewName: viewName)
        .map { .vStack($0) }
    case .zStack:
        return ZStackViewConstructor.from(arguments,
                                          viewName: viewName)
        .map { .zStack($0) }
    case .circle:
        return CircleViewConstructor.from(arguments,
                                         viewName: viewName)
        .map { .circle($0) }
    case .ellipse, .oval:
        return NoArgViewConstructor.from(arguments,
                                         viewName: viewName)
        .map { .ellipse($0) }
    case .rectangle:
        return RectangleViewConstructor.from(arguments,
                                             viewName: viewName)
        .map { .rectangle($0) }
    case .stitchRealityView:
        return StitchRealityViewConstructor.from(arguments,
                                                 viewName: viewName)
        .map { .stitchRealityView($0) }
    case .box:
        return BoxViewConstructor.from(arguments,
                                       viewName: viewName)
        .map { .box($0) }
    case .cone:
        return ConeViewConstructor.from(arguments,
                                        viewName: viewName)
        .map { .cone($0) }
    case .cylinder:
        return CylinderViewConstructor.from(arguments,
                                            viewName: viewName)
        .map { .cylinder($0) }
    case .sphere:
        return SphereViewConstructor.from(arguments,
                                          viewName: viewName)
        .map { .sphere($0) }
    case .spacer:
        return SpacerViewConstructor.from(arguments,
                                          viewName: viewName)
        .map { .spacer($0) }
    case .lazyHStack:
        return LazyHStackViewConstructor.from(arguments,
                                             viewName: viewName)
            .map { .lazyHStack($0) }
    case .lazyVStack:
        return LazyVStackViewConstructor.from(arguments,
                                             viewName: viewName)
            .map { .lazyVStack($0) }
    case .anyView, .angularGradient, .asyncImage, .button, .capsule, .canvas, .chart, .color, .colorPicker, .contentUnavailableView, .controlGroup, .datePicker, .divider, .disclosureGroup, .emptyView, .forEach, .form, .gauge, .geometryReader, .grid, .gridRow, .group, .groupBox, .labeledContent, .label, .lazyHGrid, .lazyVGrid, .link, .map, .material, .menu, .model3D, .navigationLink, .navigationStack, .navigationSplit, .navigationView, .outlineGroup, .path, .preview, .progressView, .radialGradient, .realityView, .roundedRectangle, .sceneView, .scrollView, .scrollViewReader, .section, .shareLink, .slider, .snapshotView, .spriteView, .stepper, .symbolEffect, .tabView, .textEditor, .textField, .timelineSchedule, .timelineView, .toggle, .tokenField, .toolBar, .videoPlayer, .viewThatFits, .list, .linearGradient, .secureField, .alignmentGuide, .table, .picker, .unevenRoundedRectangle:
        return nil
    }
}


enum TextViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// `Text("Hello")`
    case string(SyntaxViewModifierArgumentType)
    
    /// `Text(_ key: LocalizedStringKey)`
    case localized(SyntaxViewModifierArgumentType)
    
    /// `Text(verbatim: "Raw")`
    case verbatim(SyntaxViewModifierArgumentType)
    
    /// `Text(_ attributed: AttributedString)`
    case attributed(SyntaxViewModifierArgumentType)
}

extension TextViewConstructor {
    var layer: AIGraphData_V0.Layer { .text }
    
    var arg: SyntaxViewModifierArgumentType {
        switch self {
        case .string(let syntaxViewModifierArgumentType):
            return syntaxViewModifierArgumentType
        case .localized(let syntaxViewModifierArgumentType):
            return syntaxViewModifierArgumentType
        case .verbatim(let syntaxViewModifierArgumentType):
            return syntaxViewModifierArgumentType
        case .attributed(let syntaxViewModifierArgumentType):
            return syntaxViewModifierArgumentType
        }
    }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        let arg = self.arg
        guard let value = try arg.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        
        return [.init(input: .text, inputData: value)]
    }
    
    // Factory that infers the correct overload from a `FunctionCallExprSyntax`
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> TextViewConstructor? {
        guard let first = args.first else {
            return nil
        }
        
        // Text("Hello")
        if args.count == 1, first.label == nil {
            // Text(LocalizedStringKey("key"))
            if let call = first.value.complexValue,
               let firstStringArg = call.arguments.first {
                if call.typeName == "LocalizedStringKey" {
                    return .localized(firstStringArg.value)
                }
                
                // Text(AttributedString("Fancy"))
                if call.typeName == "AttributedString" {
                    return .attributed(firstStringArg.value)
                }
            }
            
            return .string(first.value)
        }
        
        // Text(verbatim: "Raw")
        if first.label == "verbatim" {
            return .verbatim(first.value)
        }
        
        // If it's some other expression like Text(title)
        return .string(first.value)
    }
}


enum ImageViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// `Image("assetName", bundle: nil)`
    case asset(name: SyntaxViewModifierArgumentType)
    /// `Image(systemName: "gear")`
    case sfSymbol(name: SyntaxViewModifierArgumentType)
    /// `Image(decorative:name:bundle:)`
    case decorative(name: SyntaxViewModifierArgumentType)
    /// `Image(uiImage:)`
    case uiImage(image: SyntaxViewModifierArgumentType)
    
    var layer: AIGraphData_V0.Layer {
        switch self {
        case .sfSymbol:
            return .sfSymbol
            
        default:
            return .image
        }
    }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        switch self {
            
        case .asset(let arg),
                .decorative(let arg),
                .uiImage(let arg):
            guard let portValue = try arg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            return [
                .init(input: .image,
                      inputData: portValue)
            ]
            
        case .sfSymbol(let arg):
            guard let portValue = try arg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            return [
                .init(input: .sfSymbol,
                      inputData: portValue)
            ]
        }
    }
    
    // Factory that infers the correct overload from a `FunctionCallExprSyntax`
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> ImageViewConstructor? {
        guard let first = args.first else { return nil }
        
        // 1. Image(systemName:)
        if first.label == "systemName" {
            return .sfSymbol(name: first.value)
        }
        
        // 2. Image("asset"[, bundle:])
        if first.label == nil {
            return .asset(name: first.value)
        }
        
        // 3. Image(decorative: "name"[, bundle:])
        if first.label == "decorative" {
            return .decorative(name: first.value)
        }
        
        // 4. Image(uiImage:)
        if first.label == "uiImage" {
            return .uiImage(image: first.value)
        }
        
        return nil
    }
}


enum SpacerViewConstructor: Equatable, FromSwiftUIViewToStitch {
    // TODO: support `Spacer(minLength: CGFloat? = nil)`
    case plain
    
    var layer: AIGraphData_V0.Layer { .spacer }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        // args.isEmpty ? .plain : nil
        .plain
    }
}

// MARK: - Reality-view primitives (no-arg)

// 1) StitchRealityView ---------------------------------------------------
enum StitchRealityViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                              // StitchRealityView()
    
    var layer: AIGraphData_V0.Layer { .realityView }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .plain : nil
    }
}

// 2) Box -----------------------------------------------------------------
enum BoxViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                              // Box()
    
    var layer: AIGraphData_V0.Layer { .box }
    
    // needs to become a child of the RealityView -- how does
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .plain : nil
    }
}

// 3) Cone ----------------------------------------------------------------
enum ConeViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                              // Cone()
    
    var layer: AIGraphData_V0.Layer { .cone }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .plain : nil
    }
}

// 4) Cylinder ------------------------------------------------------------
enum CylinderViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                              // Cylinder()
    
    var layer: AIGraphData_V0.Layer { .cylinder }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .plain : nil
    }
}

// 5) Sphere --------------------------------------------------------------
enum SphereViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                              // Sphere()
    
    var layer: AIGraphData_V0.Layer { .sphere }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .plain : nil
    }
}

// MARK: - Stack‑like container constructors  ──────────────────────────────
//
//  Each enum mirrors the three overloads that all four stack types share:
//      • init(alignment:…, spacing:…, content:)
//      • init(alignment:…, content:)                (spacing defaults to nil)
//      • init(spacing:…, content:)                  (alignment defaults)
//      • init(content:)                             (both defaults)
//

// TODO: could be a `struct`, since
enum HStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI actually exposes *one* public initializer:
    /// `init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)`
    /// We model that with a single enum case whose associated values carry whatever the
    /// call site provided—using `.center` and `nil` when the developer omitted them.
    case parameters(alignment: SyntaxViewModifierArgumentType?,
                    spacing:   SyntaxViewModifierArgumentType?)
    
    var layer: AIGraphData_V0.Layer { .group }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var list: [ASTCustomInputValue] = [
            .init(input: .orientation, value: .orientation(.horizontal))
        ]
        
        guard case let .parameters(alignmentArg, spacingArg) = self else { return [] }
        
        switch alignmentArg {
        case .none:
            // Default to center align
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(.centerCenter)))
            
        case .memberAccess(let memberAccess):
            // Alignment values without PortValueDescription
            guard let vertAlignment = memberAccess.vertAlignLiteral else {
                throw SwiftUISyntaxError.unsupportedConstructorForPortValueDecoding(.hStack(self))
            }
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(vertAlignment.toAnchoring)))
            
        case .some(let alignmentArg):
            guard let value = try alignmentArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            list.append(.init(input: .layerGroupAlignment,
                              inputData: value))
        }
        
        if let spacingArg = spacingArg {
            guard let value = try spacingArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            list.append(.init(input: .spacing,
                              inputData: value))
        }
        
        return list
    }
    
    // MARK: Parse from SwiftSyntax
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> HStackViewConstructor? {
        var alignment: SyntaxViewModifierArgumentType?
        var spacing: SyntaxViewModifierArgumentType?
        
        // iterate through labelled args
        for arg in args {
            switch arg.label {
            case "alignment":
                alignment = arg.value
                
            case "spacing":
                spacing = arg.value
            default:
                // ignore other labels (content closure etc.)
                break
            }
        }
        
        return .parameters(alignment: alignment, spacing: spacing)
    }
    
}



// MARK: VStackViewConstructor (new-style)
enum VStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI exposes one public initializer:
    /// `init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)`
    /// We capture what the call-site provided; defaults are implied when omitted.
    case parameters(alignment: SyntaxViewModifierArgumentType?,
                    spacing:   SyntaxViewModifierArgumentType?)

    var layer: AIGraphData_V0.Layer { .group }

    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var list: [ASTCustomInputValue] = [
            .init(input: .orientation, value: .orientation(.vertical))
        ]

        guard case let .parameters(alignmentArg, spacingArg) = self else { return [] }

        // --- alignment (HorizontalAlignment) → .layerGroupAlignment (Anchoring) ---
        switch alignmentArg {
        case .none:
            // Default center when no alignment is provided
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(.centerCenter)))

        case .memberAccess(let memberAccess):
            // Prefer literal decode helper if available
            if let horiz = memberAccess.horizAlignLiteral {
                list.append(.init(input: .layerGroupAlignment,
                                  value: .anchoring(horiz.toAnchoring)))
            } else {
                throw SwiftUISyntaxError.unsupportedConstructorForPortValueDecoding(.vStack(self))
            }

        case .some(let alignmentArg):
            guard let value = try alignmentArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .layerGroupAlignment, inputData: value))
        }

        // --- spacing (CGFloat?) → .spacing ---
        if let spacingArg = spacingArg {
            guard let value = try spacingArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .spacing, inputData: value))
        }

        return list
    }

    // MARK: Parse from SwiftSyntax
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> VStackViewConstructor? {
        var alignment: SyntaxViewModifierArgumentType?
        var spacing:   SyntaxViewModifierArgumentType?

        for arg in args {
            switch arg.label {
            case "alignment":
                alignment = arg.value
            case "spacing":
                spacing = arg.value
            default:
                break // ignore content closure or unknown labels
            }
        }

        return .parameters(alignment: alignment, spacing: spacing)
    }
}
//
//// ── Helper: random-access a TupleExprElementListSyntax by Int index ────────────
//extension LabeledExprListSyntax {
//    subscript(safe index: Int) -> LabeledExprSyntax? {
//        guard index >= 0 && index < count else { return nil }
//        return self[self.index(startIndex, offsetBy: index)]
//    }
//}
//
//enum LazyHStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    case parameters(alignment: Parameter<VerticalAlignment> = .literal(.center),
//                    spacing:   Parameter<CGFloat?>          = .literal(nil))
//
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        switch self {
//        case .parameters(let alignment, let spacing):
//            return HStackViewConstructor
//                .parameters(alignment: alignment, spacing: spacing)
//                .toStitch
//        }
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> LazyHStackViewConstructor? {
//        // Re‑use HStack parser then wrap
//        guard let base = HStackViewConstructor.from(node) else { return nil }
//        switch base {
//        case .parameters(let a, let s): return .parameters(alignment: a, spacing: s)
//        }
//    }
//}
//
//enum LazyVStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    case parameters(alignment: Parameter<HorizontalAlignment> = .literal(.center),
//                    spacing:   Parameter<CGFloat?>            = .literal(nil))
//
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        switch self {
//        case .parameters(let alignment, let spacing):
//            return VStackViewConstructor
//                .parameters(alignment: alignment, spacing: spacing)
//                .toStitch
//        }
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> LazyVStackViewConstructor? {
//        guard let base = VStackViewConstructor.from(node) else { return nil }
//        switch base {
//        case .parameters(let a, let s): return .parameters(alignment: a, spacing: s)
//        }
//    }
//}
//
//// MARK: - ZStack -----------------------------------------------------------
//
//// MARK: - TextField --------------------------------------------------------
//
//enum TextFieldViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    /// Simplified model:
//    /// `TextField(_ titleKey: LocalizedStringKey, text: Binding<String>)`
//    /// or `TextField(_ title: String, text: Binding<String>)`
//    case parameters(title: Parameter<String?> = .literal(nil),
//                    binding: ExprSyntax)          // always an expression edge
//
//    // MARK: Stitch mapping
//    ///
//    /// • `title`  →  .placeholder   (omit if nil)
//    /// • `binding`→  .text          (literal constant → value, otherwise edge)
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        guard case let .parameters(title, bindingExpr) = self else { return nil }
//        var list: [ValueOrEdge] = []
//
//        // ----- title / placeholder ---------------------------------------
//        switch title {
//        case .literal(let str?):
//            list.append(.value(.init(.placeholderText,
//                                     .string(.init(str)))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        default:
//            break    // .literal(nil)  → no placeholder
//        }
//
//        // ----- binding / text -------------------------------------------
//        if let constLiteral = bindingExpr.stringLiteralFromConstantBinding() {
//            list.append(.value(.init(.text,
//                                     .string(.init(constLiteral)))))
//        } else {
//            list.append(.edge(bindingExpr))
//        }
//
//        return (.textField, list)
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> Self? {
//        let args = node.arguments
//
//        // need at least title + binding
//        guard let first = args[safe: 0],
//              let second = args[safe: 1] else { return nil }
//
//        // First argument can be unlabeled placeholder string/localised key
//        var title: Parameter<String?> = .literal(nil)
//        if first.label == nil,
//           let lit = first.expression.as(StringLiteralExprSyntax.self) {
//            title = .literal(lit.decoded())
//        } else if first.label == nil {
//            title = .expression(first.expression)
//        }
//
//        // Second arg must be `text:` binding
//        guard second.label?.text == "text" else { return nil }
//
//        return .parameters(title: title,
//                           binding: second.expression)
//    }
//}
//
// MARK: - ZStackViewConstructor (new-style)
enum ZStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI: `init(alignment: Alignment = .center, content:)`
    case parameters(alignment: SyntaxViewModifierArgumentType?)

    var layer: AIGraphData_V0.Layer { .group }

    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var list: [ASTCustomInputValue] = []

        guard case let .parameters(alignmentArg) = self else { return [] }

        // Map Alignment → Anchoring
        switch alignmentArg {
        case .none:
            // Default is .center
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(.centerCenter)))

        case .some(let arg):
            // Prefer literal member-access if we can
            if case let .memberAccess(ma) = arg, let anch = ma.alignmentAnchoring {
                list.append(.init(input: .layerGroupAlignment,
                                  value: .anchoring(anch)))
            } else {
                // Fall back to generic port-value derivation
                guard let value = try arg.derivePortValues().first else {
                    throw SwiftUISyntaxError.portValueNotFound
                }
                list.append(.init(input: .layerGroupAlignment, inputData: value))
            }
        }

        return list
    }

    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> ZStackViewConstructor? {
        var alignment: SyntaxViewModifierArgumentType?
        for arg in args {
            if arg.label == "alignment" {
                alignment = arg.value
            }
        }
        return .parameters(alignment: alignment)
    }
}
// Helper: map SwiftUI `Alignment` member access (e.g. `.topLeading`) to Stitch `Anchoring`
private extension SyntaxViewMemberAccess {
    /// Returns a concrete `Anchoring` when this member access clearly denotes a SwiftUI `Alignment` literal.
    /// Examples: `.center`, `.top`, `.bottom`, `.leading`, `.trailing`, `.topLeading`, `.topTrailing`, `.bottomLeading`, `.bottomTrailing`.
    var alignmentAnchoring: Anchoring? {
        switch self.property {
        case "center":          return .centerCenter
        case "top":             return .topCenter
        case "bottom":          return .bottomCenter
        case "leading":         return .centerLeft
        case "trailing":        return .centerRight
        case "topLeading":      return .topLeft
        case "topTrailing":     return .topRight
        case "bottomLeading":   return .bottomLeft
        case "bottomTrailing":  return .bottomRight
        default:
            return nil
        }
    }
}
//
//// MARK: - Circle & Rectangle (no‑arg views) -------------------------------

struct NoArgViewConstructor: Equatable, FromSwiftUIViewToStitch {
    var args: [SyntaxViewArgumentData]
    var layer: AIGraphData_V0.Layer
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] { [] }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        let layer: AIGraphData_V0.Layer
        
        switch viewName {
        case .rectangle:
            layer = .rectangle
            
        case .circle, .oval:
            layer = .oval
            
        default:
            return nil
        }
        
        return .init(args: args,
                     layer: layer)
    }
}


// TODO: SwiftUI Circle can support `radius:` argument
struct CircleViewConstructor: Equatable, FromSwiftUIViewToStitch {
    
    var layer: AIGraphData_V0.Layer { .oval }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        .init()
    }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .init() : nil
    }
}

struct RectangleViewConstructor: Equatable, FromSwiftUIViewToStitch {
    
    var layer: AIGraphData_V0.Layer { .rectangle }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        .init()
    }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> Self? {
        args.isEmpty ? .init() : nil
    }
}

//// MARK: - RoundedRectangle -------------------------------------------------
//
//enum RoundedRectangleViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    /// RoundedRectangle(cornerRadius:style:)
//    case cornerRadius(radius: Parameter<CGFloat>,
//                      style:  Parameter<RoundedCornerStyle> = .literal(.continuous))
//
//    /// RoundedRectangle(cornerSize:style:)
//    case cornerSize(size: Parameter<CGSize>,
//                    style: Parameter<RoundedCornerStyle> = .literal(.continuous))
//
//    // MARK: Stitch mapping
//    ///
//    /// • RoundedRectangle(cornerRadius:) → Layer.rectangle + cornerRadius
//    /// • RoundedRectangle(cornerSize:)   → Layer.rectangle + cornerSize
//    ///
//    /// (We ignore the `style` for now; it can be added later.)
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        switch self
//        {
//        // ── cornerRadius(radius:style:) ───────────────────────────────
//        case .cornerRadius(let radius, _):
//            switch radius {
//            case .literal(let r):
//                return (
//                    .rectangle,
//                    [ .value(.init(.cornerRadius, .number(r))) ]
//                )
//            case .expression(let expr):
//                return (
//                    .rectangle,
//                    [ .edge(expr) ]
//                )
//            }
//
//        // ── cornerSize(size:style:) ───────────────────────────────────
//        case .cornerSize(let size, _):
//            switch size {
//            case .literal(let s):
//                return (
//                    .rectangle,
////                    [ .value(.init(.cornerSize, .size(s))) ]
//                    [ .value(.init(.cornerRadius, .number(s.width))) ]
//                )
//            case .expression(let expr):
//                return (
//                    .rectangle,
//                    [ .edge(expr) ]
//                )
//            }
//        }
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> Self? {
//        let args = node.arguments
//        guard let first = args.first else { return nil }
//
//        if first.label?.text == "cornerRadius" {
//            let style: Parameter<RoundedCornerStyle> = .literal(.continuous)
//            return .cornerRadius(radius: first.asParameterCGFloat(), style: style)
//        }
//        if first.label?.text == "cornerSize" {
//            let style: Parameter<RoundedCornerStyle> = .literal(.continuous)
//            return .cornerSize(size: first.asParameterCGSize(), style: style)
//        }
//        return nil
//    }
//}
//


// MARK: - ScrollView -------------------------------------------------------
enum ScrollViewViewConstructor: Equatable, FromSwiftUIViewToStitch {
    
    /// ScrollView(axes:showIndicators:)
    //    case parameters(axes: Parameter<Axis.Set> = .literal(.vertical),
    //                    showsIndicators: Parameter<Bool> = .literal(true))

    case parameters(axes: SyntaxViewModifierArgumentType?,
                    showsIndicators: SyntaxViewModifierArgumentType?)

    // Will this now always produce a group?
    var layer: AIGraphData_V0.Layer { .group }

    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard case let .parameters(axesArg, _) = self else { return [] }

        func enable(_ port: LayerInputPort) -> ASTCustomInputValue {
            .init(input: port, value: .bool(true))
        }

        // ── Default when no `axes:` parameter is supplied
        if axesArg == nil {
            return [
                enable(.scrollYEnabled),
                .init(input: .orientation,
                      value: .orientation(.vertical))
            ]
        }

        var enableX = false
        var enableY = false

        switch axesArg! {

        // ----- .horizontal / .vertical / .all ------------------------------
        case .memberAccess(let ma):
            switch ma.property {
            case "horizontal": enableX = true
            case "vertical":   enableY = true
            case "all":        enableX = true; enableY = true
            default:
                throw SwiftUISyntaxError
                    .unsupportedConstructorForPortValueDecoding(.scrollView(self))
            }

        // ----- [.horizontal, .vertical] etc. -------------------------------
        case .array(let elements):
            for el in elements {
                if case let .memberAccess(ma) = el {
                    switch ma.property {
                    case "horizontal": enableX = true
                    case "vertical":   enableY = true
                    default: break
                    }
                }
            }
            if !enableX && !enableY {
                throw SwiftUISyntaxError
                    .unsupportedConstructorForPortValueDecoding(.scrollView(self))
            }

        case .complex(let complexType):
            return try handleComplexArgumentType(
                complexType,
                // Not relevant when working with `PortValueDescription` ?
                context: nil)

            // What does PVD for `[.horizontal, .vertical]` look like? Do we get one PVD, or multiple?
            // The returned PortValue is just a bool, i.e. not enough to tell us
            .map { pv in
                    // TODO: there's not really a good way to turn
                    // Can't know
                    ASTCustomInputValue(input: .scrollYEnabled,
                                        inputData: pv)
                }

        default:
            throw SwiftUISyntaxError
                .unsupportedConstructorForPortValueDecoding(.scrollView(self))
        }

        // Assemble events ---------------------------------------------------
        var events: [ASTCustomInputValue] = []
        if enableX { events.append(enable(.scrollXEnabled)) }
        if enableY { events.append(enable(.scrollYEnabled)) }

        let orientationValue: PortValue = .orientation(
            (enableX && !enableY) ? .horizontal : .vertical
        )
        events.append(.init(input: .orientation, value: orientationValue))

        return events
    }

    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> ScrollViewViewConstructor? {
        // SwiftUI defaults: vertical scrolling & indicators shown
        var axes: SyntaxViewModifierArgumentType?
        var indicators: SyntaxViewModifierArgumentType?

        //        var axes: Parameter<Axis.Set> = .literal(.vertical)
        //        var indicators: Parameter<Bool> = .literal(true)

        for arg in args {
            // Identify the parameter by `label`
            switch arg.label {
            case nil,            // first unlabeled param is `Axis.Set`
                "axes":
                axes = arg.value

            case "showsIndicators":
                //                if let bool = arg.value.boolLiteral {
                //                    indicators = .literal(bool)
                //                }
                indicators = arg.value

            default:
                break       // ignore `content:` closure and any unknown labels
            }
        }

        return .parameters(axes: axes, showsIndicators: indicators)
    }
}



//// MARK: - Gradients --------------------------------------------------------
//
//enum AngularGradientViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    /// AngularGradient(colors:center:startAngle:endAngle:)
//    case parameters(colors: Parameter<[Color]>,
//                    center: Parameter<UnitPoint>,
//                    startAngle: Parameter<CGFloat>,
//                    endAngle:   Parameter<CGFloat>)
//
//    // MARK: Stitch mapping
//    ///
//    /// SwiftUI                      → Stitch
//    /// ---------------------------------------------------------
//    /// colors[0]                    → .startColor
//    /// colors[1]                    → .endColor
//    /// center                       → .centerAnchor
//    /// startAngle                   → .startAngle
//    /// endAngle                     → .endAngle
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        guard case let .parameters(colors, center, startAngle, endAngle) = self else { return nil }
//        var list: [ValueOrEdge] = []
//
//        // ----- colors ---------------------------------------------------
//        switch colors {
//        case .literal(let arr) where arr.count >= 2:
//            list.append(.value(.init(.startColor, .color(.init(arr[0])))))
//            list.append(.value(.init(.endColor,   .color(.init(arr[1])))))
//        case .expression(let expr):
//            list.append(.edge(expr))        // expression supplies [Color]
//        default:
//            break
//        }
//
//        // ----- center / centerAnchor -----------------------------------
//        switch center {
//        case .literal(let p):
//            list.append(.value(.init(.centerAnchor, .anchoring(p.toAnchoring))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        // ----- startAngle ----------------------------------------------
//        switch startAngle {
//        case .literal(let deg):
//            list.append(.value(.init(.startAngle, .number(deg))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        // ----- endAngle -------------------------------------------------
//        switch endAngle {
//        case .literal(let deg):
//            list.append(.value(.init(.endAngle, .number(deg))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        return (.angularGradient, list)
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> Self? {
//        let args = node.arguments
//        guard let colorsArg = args[safe: 0],
//              let centerArg = args[safe: 1],
//              let startArg  = args[safe: 2],
//              let endArg    = args[safe: 3] else { return nil }
//
//        // colors
//        let colors: Parameter<[Color]>
//        if let arr = colorsArg.expression.literalArray({ $0.colorLiteral }),
//           arr.count >= 2 {
//            colors = .literal(arr)
//        } else {
//            colors = .expression(colorsArg.expression)
//        }
//
//        // center
//        let center: Parameter<UnitPoint> = centerArg.unitPointLiteral
//            .map(Parameter.literal) ?? .expression(centerArg.expression)
//
//        // angles
//        func angleParam(_ a: LabeledExprSyntax) -> Parameter<CGFloat> {
//            if let deg = a.angleDegreesLiteral { return .literal(deg) }
//            if let num = a.cgFloatValue       { return .literal(num) }
//            return .expression(a.expression)
//        }
//
//        return .parameters(colors: colors,
//                           center: center,
//                           startAngle: angleParam(startArg),
//                           endAngle:   angleParam(endArg))
//    }
//}
//
//enum LinearGradientViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    /// LinearGradient(colors:startPoint:endPoint:)
//    case parameters(colors: Parameter<[Color]>,
//                    startPoint: Parameter<UnitPoint>,
//                    endPoint: Parameter<UnitPoint>)
//
//    // MARK: Stitch mapping
//    ///
//    /// SwiftUI                      → Stitch
//    /// ---------------------------------------------------------
//    /// colors[0]                    → .startColor   (Color)
//    /// colors[1]                    → .endColor     (Color)
//    /// startPoint (UnitPoint)       → .startAnchor  (Anchoring)
//    /// endPoint   (UnitPoint)       → .endAnchor    (Anchoring)
//    ///
//    /// Expression arguments become `.edge(expr)`.
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        guard case let .parameters(colors, startPoint, endPoint) = self else { return nil }
//        var list: [ValueOrEdge] = []
//
//        // ---- colors ----------------------------------------------------
//        switch colors {
//        case .literal(let arr) where arr.count >= 2:
//            list.append(.value(.init(.startColor, .color(.init(arr[0])))))
//            list.append(.value(.init(.endColor,   .color(.init(arr[1])))))
//        case .expression(let expr):
//            list.append(.edge(expr))         // upstream produces [Color]
//        default:
//            break
//        }
//
//        // ---- startPoint / startAnchor ---------------------------------
//        switch startPoint {
//        case .literal(let p):
//            list.append(.value(.init(.startAnchor, .anchoring(p.toAnchoring))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        // ---- endPoint / endAnchor -------------------------------------
//        switch endPoint {
//        case .literal(let p):
//            list.append(.value(.init(.endAnchor, .anchoring(p.toAnchoring))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        return (.linearGradient, list)
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> Self? {
//        let args = node.arguments
//        guard let colorsArg = args[safe: 0],
//              let startArg  = args[safe: 1],
//              let endArg    = args[safe: 2] else { return nil }
//
//        // colors
//        let colors: Parameter<[Color]>
//        if let arr = colorsArg.expression.literalArray({ $0.colorLiteral }),
//           arr.count >= 2 {
//            colors = .literal(arr)
//        } else {
//            colors = .expression(colorsArg.expression)
//        }
//
//        // points
//        let startPt: Parameter<UnitPoint> = startArg.unitPointLiteral
//            .map(Parameter.literal) ?? .expression(startArg.expression)
//        let endPt: Parameter<UnitPoint> = endArg.unitPointLiteral
//            .map(Parameter.literal) ?? .expression(endArg.expression)
//
//        return .parameters(colors: colors, startPoint: startPt, endPoint: endPt)
//    }
//}
//
//enum RadialGradientViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    /// RadialGradient(colors:center:startRadius:endRadius:)
//    case parameters(colors: Parameter<[Color]>,
//                    center: Parameter<UnitPoint>,
//                    startRadius: Parameter<CGFloat>,
//                    endRadius: Parameter<CGFloat>)
//
//    // MARK: Stitch mapping
//    ///
//    ///  SwiftUI            → Stitch
//    ///  ---------------------------------------------------------
//    ///  center             → .startAnchor          (Anchoring)
//    ///  colors[0]          → .startColor           (Color)
//    ///  colors[1]          → .endColor             (Color)
//    ///  startRadius        → .startRadius          (Number)
//    ///  endRadius          → .endRadius            (Number)
//    ///
//    ///  If any argument is an expression we emit an `.edge(expr)` instead.
//    var toStitch: (Layer?, [ValueOrEdge])? {
//        guard case let .parameters(colors, center, startRadius, endRadius) = self else { return nil }
//        var list: [ValueOrEdge] = []
//
//        // -------- colors -------------------------------------------------
//        switch colors {
//        case .literal(let arr) where arr.count >= 2:
//            list.append(.value(.init(.startColor, .color(.init(arr[0])))))
//            list.append(.value(.init(.endColor,   .color(.init(arr[1])))))
//        case .expression(let expr):
//            list.append(.edge(expr))           // upstream node outputs [Color]
//        default:
//            break
//        }
//
//        // -------- center / startAnchor ----------------------------------
//        switch center {
//        case .literal(let pt):
//            list.append(.value(.init(.startAnchor, .anchoring(pt.toAnchoring))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        // -------- startRadius -------------------------------------------
//        switch startRadius {
//        case .literal(let r):
//            list.append(.value(.init(.startRadius, .number(r))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        // -------- endRadius ---------------------------------------------
//        switch endRadius {
//        case .literal(let r):
//            list.append(.value(.init(.endRadius, .number(r))))
//        case .expression(let expr):
//            list.append(.edge(expr))
//        }
//
//        return (.radialGradient, list)
//    }
//
//    static func from(_ node: FunctionCallExprSyntax) -> Self? {
//        let args = node.arguments
//        guard args.count >= 4 else { return nil }
//
//        // ----- colors ---------------------------------------------------
//        let colors: Parameter<[Color]>
//        if let arr = args[safe: 0]!.expression.literalArray({ $0.colorLiteral }),
//           arr.count >= 2 {
//            colors = .literal(arr)
//        } else {
//            colors = .expression(args[safe: 0]!.expression)
//        }
//
//        // ----- center (UnitPoint) --------------------------------------
//        let centerArg = args[safe: 1]!
//        let center: Parameter<UnitPoint> = centerArg.unitPointLiteral
//            .map(Parameter.literal) ?? .expression(centerArg.expression)
//
//        // ----- startRadius / endRadius ---------------------------------
//        func radiusParam(_ arg: LabeledExprSyntax) -> Parameter<CGFloat> {
//            if let num = arg.cgFloatValue { return .literal(num) }
//            return .expression(arg.expression)
//        }
//        let startR = radiusParam(args[safe: 2]!)
//        let endR   = radiusParam(args[safe: 3]!)
//
//        return .parameters(colors: colors,
//                           center: center,
//                           startRadius: startR,
//                           endRadius:   endR)
//    }
//}

// TODO: consolidate the code between LazyHStackViewConstructor and HStackViewConstructor, etc.
// MARK: LazyHStackViewConstructor (new-style)
enum LazyHStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI: `init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)`
    case parameters(alignment: SyntaxViewModifierArgumentType?,
                    spacing:   SyntaxViewModifierArgumentType?)

    var layer: AIGraphData_V0.Layer { .group }

    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
                
        var list: [ASTCustomInputValue] = [
            .init(input: .orientation, value: .orientation(.horizontal))
        ]
        guard case let .parameters(alignmentArg, spacingArg) = self else { return list }

        // alignment (VerticalAlignment) → .layerGroupAlignment (Anchoring)
        switch alignmentArg {
        case .none:
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(.centerCenter)))
        case .memberAccess(let ma):
            guard let v = ma.vertAlignLiteral else {
                throw SwiftUISyntaxError.unsupportedConstructorForPortValueDecoding(.hStack(HStackViewConstructor.parameters(alignment: nil, spacing: nil)))
            }
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(v.toAnchoring)))
        case .some(let arg):
            guard let value = try arg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .layerGroupAlignment, inputData: value))
        }

        if let spacingArg = spacingArg {
            guard let value = try spacingArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .spacing, inputData: value))
        }
        return list
    }

    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> LazyHStackViewConstructor? {
        
        var alignment: SyntaxViewModifierArgumentType?
        var spacing:   SyntaxViewModifierArgumentType?
        for arg in args {
            switch arg.label {
            case "alignment": alignment = arg.value
            case "spacing":   spacing   = arg.value
            // ignore pinnedViews / content / unknown
            default: break
            }
        }
        return .parameters(alignment: alignment, spacing: spacing)
    }
}

// MARK: LazyVStackViewConstructor (new-style)
enum LazyVStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI: `init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)`
    case parameters(alignment: SyntaxViewModifierArgumentType?,
                    spacing:   SyntaxViewModifierArgumentType?)

    var layer: AIGraphData_V0.Layer { .group }

    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var list: [ASTCustomInputValue] = [
            .init(input: .orientation, value: .orientation(.vertical))
        ]
        guard case let .parameters(alignmentArg, spacingArg) = self else { return list }

        // alignment (HorizontalAlignment) → .layerGroupAlignment (Anchoring)
        switch alignmentArg {
        case .none:
            list.append(.init(input: .layerGroupAlignment,
                              value: .anchoring(.centerCenter)))
        case .memberAccess(let ma):
            if let h = ma.horizAlignLiteral {
                list.append(.init(input: .layerGroupAlignment,
                                  value: .anchoring(h.toAnchoring)))
            } else {
                throw SwiftUISyntaxError.unsupportedConstructorForPortValueDecoding(.vStack(VStackViewConstructor.parameters(alignment: nil, spacing: nil)))
            }
        case .some(let arg):
            guard let value = try arg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .layerGroupAlignment, inputData: value))
        }

        if let spacingArg = spacingArg {
            guard let value = try spacingArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .spacing, inputData: value))
        }
        return list
    }

    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> LazyVStackViewConstructor? {
        var alignment: SyntaxViewModifierArgumentType?
        var spacing:   SyntaxViewModifierArgumentType?
        for arg in args {
            switch arg.label {
            case "alignment": alignment = arg.value
            case "spacing":   spacing   = arg.value
            default: break
            }
        }
        return .parameters(alignment: alignment, spacing: spacing)
    }
}


// MARK: - View Modifier Support

/// Strict (typed) container for all supported SwiftUI view modifiers we map to Stitch.
/// Mirrors how `ViewConstructor` wraps typed view constructors.
/// Each case carries the specific typed modifier struct/enum and exposes a unified
/// `value` that conforms to `FromSwiftUIViewModifierToStitch`.
enum StrictViewModifier: Equatable, Encodable {
    case opacity(OpacityViewModifier)
    case scaleEffect(ScaleEffectViewModifier)
    case blur(BlurViewModifier)
    case zIndex(ZIndexViewModifier)
    case cornerRadius(CornerRadiusViewModifier)
    case frame(FrameViewModifier)
    case foregroundColor(ForegroundColorViewModifier)
    case fill(FillViewModifier)
    case brightness(BrightnessViewModifier)
    case contrast(ContrastViewModifier)
    case saturation(SaturationViewModifier)
    case hueRotation(HueRotationViewModifier)
    case colorInvert(ColorInvertViewModifier)
    case position(PositionViewModifier)
    case offset(OffsetViewModifier)
    case padding(PaddingViewModifier)
    case clipped(ClippedViewModifier)
    case font(FontViewModifier)
    case fontDesign(FontDesignViewModifier)
    case fontWeight(FontWeightViewModifier)
    case layerId(LayerIdViewModifier)
    // Add further cases here as new typed modifiers are introduced

    /// Type-erased access to the underlying typed modifier for Stitch emission.
    var value: any FromSwiftUIViewModifierToStitch {
        switch self {
        case .opacity(let m):        return m
        case .scaleEffect(let m):    return m
        case .blur(let m):           return m
        case .zIndex(let m):         return m
        case .cornerRadius(let m):   return m
        case .frame(let m):          return m
        case .foregroundColor(let m): return m
        case .fill(let m):           return m
        case .brightness(let m):     return m
        case .contrast(let m):       return m
        case .saturation(let m):     return m
        case .hueRotation(let m):    return m
        case .colorInvert(let m):    return m
        case .position(let m):       return m
        case .offset(let m):         return m
        case .padding(let m):        return m
        case .clipped(let m):        return m
        case .font(let m):           return m
        case .fontDesign(let m):     return m
        case .fontWeight(let m):     return m
        case .layerId(let m):        return m
        }
    }
}

protocol FromSwiftUIViewModifierToStitch: Encodable {
    associatedtype T
    
    static func from(_ args: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> T?
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue]
}

// MARK: - Opacity View Modifier

struct OpacityViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let value: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try value.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        
        return [.init(input: .opacity, inputData: portValue)]
    }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> OpacityViewModifier? {
        guard modifierName == .opacity,
              let first = args.first,
              first.label == nil else {
            return nil
        }
        
        return OpacityViewModifier(value: first.value)
    }
}

// MARK: - ScaleEffect View Modifier
enum ScaleEffectViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    // SwiftUI overloads we support
    // 1) .scaleEffect(2.0, anchor: .center)
    case uniform(scale: SyntaxViewModifierArgumentType,
                 anchor: SyntaxViewModifierArgumentType?)
    // 2) .scaleEffect(x: 2, y: 3, anchor: .top)
    case xy(x: SyntaxViewModifierArgumentType,
            y: SyntaxViewModifierArgumentType,
            anchor: SyntaxViewModifierArgumentType?)
    // 3) .scaleEffect(CGSize(width: 2, height: 3), anchor: .center)
    case size(size: SyntaxViewModifierArgumentType,
              anchor: SyntaxViewModifierArgumentType?)

    // MARK: - Stitch mapping
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // local helper for optional anchor → .pivot
        func pivotEvents(_ anchorArg: SyntaxViewModifierArgumentType?) throws -> [ASTCustomInputValue] {
            guard let anchorArg else { return [] }
            if case let .memberAccess(ma) = anchorArg, let anch = ma.unitPointAnchoring {
                return [.init(input: .pivot, value: .anchoring(anch))]
            }
            if let anchorPV = try anchorArg.derivePortValues().first {
                return [.init(input: .pivot, inputData: anchorPV)]
            }
            throw SwiftUISyntaxError.portValueNotFound
        }

        switch self {
        case .uniform(let scaleArg, let anchorArg):
            guard let pv = try scaleArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            var events: [ASTCustomInputValue] = [.init(input: .scale, inputData: pv)]
            events += try pivotEvents(anchorArg)
            return events

        case .xy(let xArg, let yArg, let anchorArg):
            guard let x = try xArg.derivePortValues().first?.value,
                  let y = try yArg.derivePortValues().first?.value else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            let portValueX = try PortValue(from: x)
            let portValueY = try PortValue(from: y)
            
            guard portValueX == portValueY else {
                throw SwiftUISyntaxError.unsupportedSyntaxArgument("scaleEffect(x:y:) requires uniform scale for Stitch .scale")
            }
            var events: [ASTCustomInputValue] = [.init(input: .scale, value: portValueX)]
            events += try pivotEvents(anchorArg)
            return events

        case .size(let sizeArg, let anchorArg):
            // Expect tuple(width:, height:) with equal values for uniform scale
            if case .tuple(let fields) = sizeArg,
               let wField = fields.first(where: { $0.label == "width" })?.value,
               let hField = fields.first(where: { $0.label == "height" })?.value,
               let w = try wField.derivePortValues().first?.value,
               let h = try hField.derivePortValues().first?.value {
                let portValueW = try PortValue(from: w)
                let portValueH = try PortValue(from: h)
                
                if portValueW == portValueH {
                    var events: [ASTCustomInputValue] = [.init(input: .scale, value: portValueW)]
                    events += try pivotEvents(anchorArg)
                    return events
                }
                
            }
            throw SwiftUISyntaxError.unsupportedSyntaxArgument("scaleEffect(CGSize) requires uniform width/height for Stitch .scale")
        }
    }

    // MARK: - Parse from SwiftSyntax
    static func from(_ args: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> ScaleEffectViewModifier? {
        guard modifierName == .scaleEffect else { return nil }

        var unlabeled: SyntaxViewModifierArgumentType?
        var xArg: SyntaxViewModifierArgumentType?
        var yArg: SyntaxViewModifierArgumentType?
        var anchorArg: SyntaxViewModifierArgumentType?

        for a in args {
            switch a.label {
            case nil:
                unlabeled = a.value
            case "x":
                xArg = a.value
            case "y":
                yArg = a.value
            case "anchor":
                anchorArg = a.value
            default:
                break
            }
        }

        // x/y variant takes precedence when either is present
        if xArg != nil || yArg != nil {
            let x = xArg ?? .simple(.init(value: "1.0", syntaxKind: .float))
            let y = yArg ?? .simple(.init(value: "1.0", syntaxKind: .float))
            return .xy(x: x, y: y, anchor: anchorArg)
        }

        // Distinguish CGSize vs scalar
        if let unlabeled {
            let isCGSize: Bool
            switch unlabeled {
            case .tuple(let fields):
                isCGSize = fields.contains(where: { $0.label == "width" }) &&
                           fields.contains(where: { $0.label == "height" })
            case .complex(let c):
                isCGSize = c.typeName.contains("CGSize")
            default:
                isCGSize = false
            }

            return isCGSize
                ? .size(size: unlabeled, anchor: anchorArg)
                : .uniform(scale: unlabeled, anchor: anchorArg)
        }

        return nil
    }
}

// Helper: map UnitPoint-like member access (e.g. `.center`) to Anchoring
extension SyntaxViewMemberAccess {
    var unitPointAnchoring: Anchoring? {
        switch self.property {
        case "center":         return .centerCenter
        case "top":            return .topCenter
        case "bottom":         return .bottomCenter
        case "leading":        return .centerLeft
        case "trailing":       return .centerRight
        case "topLeading":     return .topLeft
        case "topTrailing":    return .topRight
        case "bottomLeading":  return .bottomLeft
        case "bottomTrailing": return .bottomRight
        default: return nil
        }
    }
}

// MARK: - Blur View Modifier

struct BlurViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let radius: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try radius.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        
        return [.init(input: .blur, inputData: portValue)]
    }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> BlurViewModifier? {
        guard modifierName == .blur else { return nil }
        
        // Find radius argument (either labeled "radius" or first unlabeled)
        if let radiusArg = args.first(where: { $0.label == "radius" }) {
            return BlurViewModifier(radius: radiusArg.value)
        } else if let first = args.first, first.label == nil {
            return BlurViewModifier(radius: first.value)
        }
        
        return nil
    }
}

// MARK: - ZIndex View Modifier

struct ZIndexViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let value: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try value.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        
        return [.init(input: .zIndex, inputData: portValue)]
    }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> ZIndexViewModifier? {
        guard modifierName == .zIndex,
              let first = args.first,
              first.label == nil else {
            return nil
        }
        
        return ZIndexViewModifier(value: first.value)
    }
}

// MARK: - CornerRadius View Modifier

struct CornerRadiusViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let radius: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try radius.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        
        return [.init(input: .cornerRadius, inputData: portValue)]
    }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> CornerRadiusViewModifier? {
        guard modifierName == .cornerRadius,
              let first = args.first,
              first.label == nil else {
            return nil
        }
        
        return CornerRadiusViewModifier(radius: first.value)
    }
}

// MARK: - Frame View Modifier

struct FrameViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let width: SyntaxViewModifierArgumentType?
    let height: SyntaxViewModifierArgumentType?
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var result: [ASTCustomInputValue] = []
        
        // Handle width argument
        if let width = width {
            let widthPortDerivations = try width.derivePortValues()
            for derivation in widthPortDerivations {
                
                let customValue = ASTCustomInputValue(
                    coordinate: CurrentAIGraphData.LayerInputType.init(layerInput: .size,
                                                                       portType: .unpacked(.port0)),
                    inputData: derivation)
                
                result.append(customValue)
            }
        }
        
        // Handle height argument  
        if let height = height {
            let heightPortDerivations = try height.derivePortValues()
            for derivation in heightPortDerivations {
                
                let customValue = ASTCustomInputValue(
                    coordinate: CurrentAIGraphData.LayerInputType.init(layerInput: .size,
                                                                       portType: .unpacked(.port1)),
                    inputData: derivation)
                
                result.append(customValue)
            }
        }
        
        // If no width or height provided, create default size
        if result.isEmpty {
            let layerSize = LayerSize(width: .auto, height: .auto)
            result.append(ASTCustomInputValue(input: .size, value: .size(layerSize)))
        }
        
        return result
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> FrameViewModifier? {
        var width: SyntaxViewModifierArgumentType?
        var height: SyntaxViewModifierArgumentType?
        
        for arg in arguments {
            switch arg.label {
            case "width":  width = arg.value
            case "height": height = arg.value
            default: break
            }
        }
        
        // Require at least one dimension to be present
        guard width != nil || height != nil else { return nil }
        
        return FrameViewModifier(width: width, height: height)
    }
}

// MARK: - Color View Modifiers

struct ForegroundColorViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let color: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // First try to parse as Color type for semantic colors like .blue
        if case let .memberAccess(memberAccess) = color {
            let colorStr = memberAccess.property
            if let color = Color.fromSystemName(colorStr) {
                return [ASTCustomInputValue(input: .color, value: .color(color))]
            }
        }
        
        // Fall back to generic port value derivation
        guard let colorPortValue = try color.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        return [ASTCustomInputValue(input: .color, inputData: colorPortValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> ForegroundColorViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return ForegroundColorViewModifier(color: first.value)
    }
}

struct FillViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let color: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // First try to parse as Color type for semantic colors like .blue
        if case let .memberAccess(memberAccess) = color {
            let colorStr = memberAccess.property
            if let color = Color.fromSystemName(colorStr) {
                return [ASTCustomInputValue(input: .color, value: .color(color))]
            }
        }
        
        // Fall back to generic port value derivation
        guard let colorPortValue = try color.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        return [ASTCustomInputValue(input: .color, inputData: colorPortValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> FillViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return FillViewModifier(color: first.value)
    }
}

// MARK: - Layer Effects View Modifiers

struct BrightnessViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let value: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try value.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        return [ASTCustomInputValue(input: .brightness, inputData: portValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> BrightnessViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return BrightnessViewModifier(value: first.value)
    }
}

struct ContrastViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let value: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try value.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        return [ASTCustomInputValue(input: .contrast, inputData: portValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> ContrastViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return ContrastViewModifier(value: first.value)
    }
}

struct SaturationViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let value: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let portValue = try value.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        return [ASTCustomInputValue(input: .saturation, inputData: portValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> SaturationViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return SaturationViewModifier(value: first.value)
    }
}

struct HueRotationViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let angle: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        guard let anglePortValue = try angle.derivePortValues().first else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        return [ASTCustomInputValue(input: .hueRotation, inputData: anglePortValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> HueRotationViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return HueRotationViewModifier(angle: first.value)
    }
}

struct ColorInvertViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    // colorInvert() takes no arguments
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        let trueValue = PortValue.bool(true)
        return [ASTCustomInputValue(input: .colorInvert, value: trueValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> ColorInvertViewModifier? {
        // colorInvert() should have no arguments
        guard arguments.isEmpty else { return nil }
        return ColorInvertViewModifier()
    }
}

// MARK: - Positioning View Modifiers

struct PositionViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let x: SyntaxViewModifierArgumentType
    let y: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var result: [ASTCustomInputValue] = []
        
        // Handle x argument
        let xPortDerivations = try x.derivePortValues()
        for derivation in xPortDerivations {
            let customValue = ASTCustomInputValue(
                coordinate: CurrentAIGraphData.LayerInputType.init(layerInput: .position,
                                                                   portType: .unpacked(.port0)),
                inputData: derivation)
            result.append(customValue)
        }
        
        // Handle y argument  
        let yPortDerivations = try y.derivePortValues()
        for derivation in yPortDerivations {
            let customValue = ASTCustomInputValue(
                coordinate: CurrentAIGraphData.LayerInputType.init(layerInput: .position,
                                                                   portType: .unpacked(.port1)),
                inputData: derivation)
            result.append(customValue)
        }
        
        return result
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> PositionViewModifier? {
        var x: SyntaxViewModifierArgumentType?
        var y: SyntaxViewModifierArgumentType?
        
        // .position(x: X, y: Y) or .position(CGPoint(x: X, y: Y))
        for arg in arguments {
            switch arg.label {
            case "x": x = arg.value
            case "y": y = arg.value
            case nil:
                // Handle CGPoint case - would need more complex parsing
                return nil
            default: break
            }
        }
        
        guard let x = x, let y = y else { return nil }
        return PositionViewModifier(x: x, y: y)
    }
}

struct OffsetViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let x: SyntaxViewModifierArgumentType
    let y: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        var result: [ASTCustomInputValue] = []
        
        // Handle x argument
        let xPortDerivations = try x.derivePortValues()
        for derivation in xPortDerivations {
            
            let customValue = ASTCustomInputValue(
                coordinate: CurrentAIGraphData.LayerInputType.init(layerInput: .offsetInGroup,
                                                                   portType: .unpacked(.port0)),
                inputData: derivation)
            
            result.append(customValue)
        }
        
        // Handle y argument  
        let yPortDerivations = try y.derivePortValues()
        for derivation in yPortDerivations {
            let customValue = ASTCustomInputValue(
                coordinate: CurrentAIGraphData.LayerInputType.init(layerInput: .offsetInGroup,
                                                                   portType: .unpacked(.port1)),
                inputData: derivation)
            
            result.append(customValue)
        }
        
        return result
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> OffsetViewModifier? {
        var x: SyntaxViewModifierArgumentType?
        var y: SyntaxViewModifierArgumentType?
        
        for arg in arguments {
            switch arg.label {
            case "x": x = arg.value
            case "y": y = arg.value
            case nil:
                // Handle CGSize case - would need more complex parsing
                return nil
            default: break
            }
        }
        
        guard let x = x, let y = y else { return nil }
        return OffsetViewModifier(x: x, y: y)
    }
}

// MARK: - Layout View Modifiers

struct PaddingViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let edges: SyntaxViewModifierArgumentType?
    let length: SyntaxViewModifierArgumentType?
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // For now, handle uniform padding only
        guard let length = length,
              let lengthPortValue = try length.derivePortValues().first?.value,
              let paddingNumber = try PortValue(from: lengthPortValue).getNumber else {
            throw SwiftUISyntaxError.portValueNotFound
        }
        
        let paddingValue = PortValue.padding(StitchPadding(
            top: paddingNumber,
            right: paddingNumber,
            bottom: paddingNumber,
            left: paddingNumber
        ))
        return [ASTCustomInputValue(input: .padding, value: paddingValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> PaddingViewModifier? {
        var edges: SyntaxViewModifierArgumentType?
        var length: SyntaxViewModifierArgumentType?
        
        for arg in arguments {
            switch arg.label {
            case "edges", nil where edges == nil:
                edges = arg.value
            case "length", nil where length == nil:
                length = arg.value
            default: break
            }
        }
        
        // Handle .padding() with no arguments - uniform 16pt padding
        if arguments.isEmpty {
            let defaultPadding = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: "16", syntaxKind: .float)
            )
            return PaddingViewModifier(edges: nil, length: defaultPadding)
        }
        
        // Handle .padding(X) - uniform X padding
        if arguments.count == 1 && arguments.first?.label == nil {
            length = arguments.first?.value
        }
        
        return PaddingViewModifier(edges: edges, length: length)
    }
}

struct ClippedViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    // .clipped() takes no arguments
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        let trueValue = PortValue.bool(true)
        return [ASTCustomInputValue(input: .isClipped, value: trueValue)]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> ClippedViewModifier? {
        // clipped() should have no arguments
        guard arguments.isEmpty else { return nil }
        return ClippedViewModifier()
    }
}

// MARK: - Font View Modifiers

struct FontViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let font: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // For .font() modifier, we need to create both textFont and fontSize events
        let fontEvents = try createFontEvents(from: font)
        return fontEvents
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> FontViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return FontViewModifier(font: first.value)
    }
}

struct FontDesignViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let design: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // FontDesign affects the fontChoice part of StitchFont
        let fontEvents = try createFontDesignEvents(from: design)
        return fontEvents
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> FontDesignViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return FontDesignViewModifier(design: first.value)
    }
}

struct FontWeightViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let weight: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // FontWeight affects the fontWeight part of StitchFont
        let fontEvents = try createFontWeightEvents(from: weight)
        return fontEvents
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> FontWeightViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return FontWeightViewModifier(weight: first.value)
    }
}

struct LayerIdViewModifier: Equatable, FromSwiftUIViewModifierToStitch {
    let layerId: SyntaxViewModifierArgumentType
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
        // LayerId modifier doesn't create LayerInputPort values,
        // it uses the layer's own ID from StrictSyntaxView/LayerData
        return []
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> LayerIdViewModifier? {
        guard let first = arguments.first,
              first.label == nil else {
            return nil
        }
        return LayerIdViewModifier(layerId: first.value)
    }
}

// MARK: - Font Helper Functions

/// Creates font events from SwiftUI .font() modifier
func createFontEvents(from fontArg: SyntaxViewModifierArgumentType) throws -> [ASTCustomInputValue] {
    // Handle .memberAccess directly (e.g., .headline, .body, .title)
    if case .memberAccess(let memberData) = fontArg,
       let swiftUIFont = parseSwiftUISystemFont(memberData.property) {
        let stitchFont = mapSwiftUIFontToStitchFont(swiftUIFont)
        let fontSize = mapSwiftUIFontToSize(swiftUIFont)
        
        return [
            ASTCustomInputValue(input: .textFont, value: .textFont(stitchFont)),
            ASTCustomInputValue(input: .fontSize, value: .number(fontSize))
        ]
    }
    
    // Handle .complex (e.g., .system(size: 16, weight: .bold))
    if case .complex(let complexData) = fontArg {
        // Parse .system() font specifications
        if complexData.typeName == "Font" || complexData.typeName.contains("system") {
            // Extract size, weight, design from arguments
            var fontSize: Double = 17 // default
            var fontChoice: StitchFontChoice = .sf
            var fontWeight: StitchFontWeight = .SF_regular
            
            for arg in complexData.arguments {
                switch arg.label {
                case "size":
                    if case .simple(let simpleData) = arg.value,
                       let size = Double(simpleData.value) {
                        fontSize = size
                    }
                case "weight":
                    if case .memberAccess(let memberData) = arg.value {
                        fontWeight = mapSwiftUIFontWeightToStitchFontWeight(memberData.property)
                    }
                case "design":
                    if case .memberAccess(let memberData) = arg.value {
                        fontChoice = mapSwiftUIFontDesignToStitchFontChoice(memberData.property)
                    }
                default:
                    break
                }
            }
            
            let stitchFont = StitchFont(fontChoice: fontChoice, fontWeight: fontWeight)
            return [
                ASTCustomInputValue(input: .textFont, value: .textFont(stitchFont)),
                ASTCustomInputValue(input: .fontSize, value: .number(fontSize))
            ]
        }
    }
    
    // Fallback: treat as generic font and use default mapping
    let defaultFont = StitchFont(fontChoice: .sf, fontWeight: .SF_regular)
    return [ASTCustomInputValue(input: .textFont, value: .textFont(defaultFont))]
}

/// Creates font design events from SwiftUI .fontDesign() modifier
func createFontDesignEvents(from designArg: SyntaxViewModifierArgumentType) throws -> [ASTCustomInputValue] {
    if case .memberAccess(let memberData) = designArg {
        let fontChoice = mapSwiftUIFontDesignToStitchFontChoice(memberData.property)
        let defaultWeight = getDefaultWeightForFontChoice(fontChoice)
        let stitchFont = StitchFont(fontChoice: fontChoice, fontWeight: defaultWeight)
        
        return [ASTCustomInputValue(input: .textFont, value: .textFont(stitchFont))]
    }
    
    // Fallback
    let defaultFont = StitchFont(fontChoice: .sf, fontWeight: .SF_regular)
    return [ASTCustomInputValue(input: .textFont, value: .textFont(defaultFont))]
}

/// Creates font weight events from SwiftUI .fontWeight() modifier
func createFontWeightEvents(from weightArg: SyntaxViewModifierArgumentType) throws -> [ASTCustomInputValue] {
    if case .memberAccess(let memberData) = weightArg {
        let fontWeight = mapSwiftUIFontWeightToStitchFontWeight(memberData.property)
        // We need to preserve the current font choice, so we'll use SF as default
        let stitchFont = StitchFont(fontChoice: .sf, fontWeight: fontWeight)
        
        return [ASTCustomInputValue(input: .textFont, value: .textFont(stitchFont))]
    }
    
    // Fallback
    let defaultFont = StitchFont(fontChoice: .sf, fontWeight: .SF_regular)
    return [ASTCustomInputValue(input: .textFont, value: .textFont(defaultFont))]
}

// MARK: - Font Mapping Functions

struct SwiftUISystemFont {
    let size: Double
    let design: StitchFontChoice
    let weight: StitchFontWeight
}

func parseSwiftUISystemFont(_ property: String) -> SwiftUISystemFont? {
    switch property {
    case "largeTitle":
        return SwiftUISystemFont(size: 34, design: .sf, weight: .SF_regular)
    case "title":
        return SwiftUISystemFont(size: 28, design: .sf, weight: .SF_regular)
    case "title2":
        return SwiftUISystemFont(size: 22, design: .sf, weight: .SF_regular)
    case "title3":
        return SwiftUISystemFont(size: 20, design: .sf, weight: .SF_regular)
    case "headline":
        return SwiftUISystemFont(size: 17, design: .sf, weight: .SF_semibold)
    case "body":
        return SwiftUISystemFont(size: 17, design: .sf, weight: .SF_regular)
    case "callout":
        return SwiftUISystemFont(size: 16, design: .sf, weight: .SF_regular)
    case "subheadline":
        return SwiftUISystemFont(size: 15, design: .sf, weight: .SF_regular)
    case "footnote":
        return SwiftUISystemFont(size: 13, design: .sf, weight: .SF_regular)
    case "caption":
        return SwiftUISystemFont(size: 12, design: .sf, weight: .SF_regular)
    case "caption2":
        return SwiftUISystemFont(size: 11, design: .sf, weight: .SF_regular)
    default:
        return nil
    }
}

func mapSwiftUIFontToStitchFont(_ swiftUIFont: SwiftUISystemFont) -> StitchFont {
    return StitchFont(fontChoice: swiftUIFont.design, fontWeight: swiftUIFont.weight)
}

func mapSwiftUIFontToSize(_ swiftUIFont: SwiftUISystemFont) -> Double {
    return swiftUIFont.size
}

func mapSwiftUIFontDesignToStitchFontChoice(_ design: String) -> StitchFontChoice {
    switch design {
    case "default":
        return .sf
    case "serif":
        return .newYorkSerif
    case "rounded":
        return .sfRounded
    case "monospaced":
        return .sfMono
    default:
        return .sf
    }
}

func mapSwiftUIFontWeightToStitchFontWeight(_ weight: String) -> StitchFontWeight {
    switch weight {
    case "ultraLight":
        return .SF_ultraLight
    case "thin":
        return .SF_thin
    case "light":
        return .SF_light
    case "regular":
        return .SF_regular
    case "medium":
        return .SF_medium
    case "semibold":
        return .SF_semibold
    case "bold":
        return .SF_bold
    case "heavy":
        return .SF_heavy
    case "black":
        return .SF_black
    default:
        return .SF_regular
    }
}

func getDefaultWeightForFontChoice(_ fontChoice: StitchFontChoice) -> StitchFontWeight {
    switch fontChoice {
    case .sf:
        return .SF_regular
    case .sfMono:
        return .SFMono_regular
    case .sfRounded:
        return .SFRounded_regular
    case .newYorkSerif:
        return .NewYorkSerif_regular
    }
}

/// Factory function to create ViewModifierConstructor from parsed SwiftUI syntax
func createKnownViewModifier(modifierName: SyntaxViewModifierName,
                           arguments: [SyntaxViewArgumentData]) -> StrictViewModifier? {
    
    switch modifierName {
    case .opacity:
        return OpacityViewModifier.from(arguments, modifierName: modifierName)
            .map { .opacity($0) }
    case .scaleEffect:
        return ScaleEffectViewModifier.from(arguments, modifierName: modifierName)
            .map { .scaleEffect($0) }
    case .blur:
        return BlurViewModifier.from(arguments, modifierName: modifierName)
            .map { .blur($0) }
    case .zIndex:
        return ZIndexViewModifier.from(arguments, modifierName: modifierName)
            .map { .zIndex($0) }
    case .cornerRadius:
        return CornerRadiusViewModifier.from(arguments, modifierName: modifierName)
            .map { .cornerRadius($0) }
    case .frame:
        return FrameViewModifier.from(arguments, modifierName: modifierName)
            .map { .frame($0) }
    case .foregroundColor:
        return ForegroundColorViewModifier.from(arguments, modifierName: modifierName)
            .map { .foregroundColor($0) }
    case .fill:
        return FillViewModifier.from(arguments, modifierName: modifierName)
            .map { .fill($0) }
    case .brightness:
        return BrightnessViewModifier.from(arguments, modifierName: modifierName)
            .map { .brightness($0) }
    case .contrast:
        return ContrastViewModifier.from(arguments, modifierName: modifierName)
            .map { .contrast($0) }
    case .saturation:
        return SaturationViewModifier.from(arguments, modifierName: modifierName)
            .map { .saturation($0) }
    case .hueRotation:
        return HueRotationViewModifier.from(arguments, modifierName: modifierName)
            .map { .hueRotation($0) }
    case .colorInvert:
        return ColorInvertViewModifier.from(arguments, modifierName: modifierName)
            .map { .colorInvert($0) }
    case .position:
        return PositionViewModifier.from(arguments, modifierName: modifierName)
            .map { .position($0) }
    case .offset:
        return OffsetViewModifier.from(arguments, modifierName: modifierName)
            .map { .offset($0) }
    case .padding:
        return PaddingViewModifier.from(arguments, modifierName: modifierName)
            .map { .padding($0) }
    case .clipped:
        return ClippedViewModifier.from(arguments, modifierName: modifierName)
            .map { .clipped($0) }
    case .font:
        return FontViewModifier.from(arguments, modifierName: modifierName)
            .map { .font($0) }
    case .fontDesign:
        return FontDesignViewModifier.from(arguments, modifierName: modifierName)
            .map { .fontDesign($0) }
    case .fontWeight:
        return FontWeightViewModifier.from(arguments, modifierName: modifierName)
            .map { .fontWeight($0) }
    case .layerId:
        return LayerIdViewModifier.from(arguments, modifierName: modifierName)
            .map { .layerId($0) }
    default:
        return nil
    }
}
