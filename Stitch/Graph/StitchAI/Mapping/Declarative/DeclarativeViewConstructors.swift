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
enum ViewConstructor: Equatable, Encodable {
    case text(TextViewConstructor)
    case image(ImageViewConstructor)
    case hStack(HStackViewConstructor)
    case vStack(VStackViewConstructor)
    case zStack(ZStackViewConstructor)
    case circle(NoArgViewConstructor)
    case ellipse(NoArgViewConstructor)
    case rectangle(NoArgViewConstructor)
    
    // Augmented Reality
    case stitchRealityView(StitchRealityViewConstructor)
    case box(BoxViewConstructor)
    case cone(ConeViewConstructor)
    case cylinder(CylinderViewConstructor)
    case sphere(SphereViewConstructor)
    
    case spacer(SpacerViewConstructor)
    
    // TODO: handle here(?), instead of as a special case
    // case scrollView(ScrollViewViewConstructor)
    
    //    case lazyHStack(LazyHStackViewConstructor)
    //    case lazyVStack(LazyVStackViewConstructor)
    //    case circle(CircleViewConstructor)
    //    case ellipse(EllipseViewConstructor)
    //    case rectangle(RectangleViewConstructor)
    //    case roundedRectangle(RoundedRectangleViewConstructor)

    //    case textField(TextFieldViewConstructor)
    //    case angularGradient(AngularGradientViewConstructor)
    //    case linearGradient(LinearGradientViewConstructor)
    //    case radialGradient(RadialGradientViewConstructor)
    
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
        case .stitchRealityView(let c): return c
        case .box(let c):               return c
        case .cone(let c):              return c
        case .cylinder(let c):          return c
        case .sphere(let c):            return c
        case .spacer(let c):            return c
        }
    }
}


/// Runs every `…ViewConstructor.from(node)` helper once. If an enum is
/// returned, attach it to the *current* SyntaxView.
func createKnownViewConstructor(from node: FunctionCallExprSyntax,
                                               arguments: [SyntaxViewArgumentData]) -> ViewConstructor? {
    
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
        return NoArgViewConstructor.from(arguments,
                                         viewName: viewName)
        .map { .circle($0) }
    case .ellipse, .oval:
        return NoArgViewConstructor.from(arguments,
                                         viewName: viewName)
        .map { .ellipse($0) }
    case .rectangle:
        return NoArgViewConstructor.from(arguments,
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
        
    case .anyView, .angularGradient, .asyncImage, .button, .capsule, .canvas, .chart, .color, .colorPicker, .contentUnavailableView, .controlGroup, .datePicker, .divider, .disclosureGroup, .emptyView, .forEach, .form, .gauge, .geometryReader, .grid, .gridRow, .group, .groupBox, .labeledContent, .label, .lazyHGrid, .lazyHStack, .lazyVGrid, .lazyVStack, .link, .map, .material, .menu, .model3D, .navigationLink, .navigationStack, .navigationSplit, .navigationView, .outlineGroup, .path, .preview, .progressView, .radialGradient, .realityView, .roundedRectangle, .sceneView, .scrollView, .scrollViewReader, .section, .shareLink, .slider, .snapshotView, .spriteView, .stepper, .symbolEffect, .tabView, .textEditor, .textField, .timelineSchedule, .timelineView, .toggle, .tokenField, .toolBar, .videoPlayer, .viewThatFits, .list, .linearGradient, .secureField, .alignmentGuide, .table, .picker, .unevenRoundedRectangle:
        return nil
        
//    case .scrollView:
//        if let ctor = ScrollViewViewConstructor.from(arguments) {
//            return .scrollView(ctor)
//        }
//
//        case .vStack:
//            if let ctor = VStackViewConstructor.from(node).map(ViewConstructor.vStack) {
//                attachConstructor(ctor)
//            }
//        case .lazyHStack:
//            if let ctor = LazyHStackViewConstructor.from(node).map(ViewConstructor.lazyHStack) {
//                attachConstructor(ctor)
//            }
//        case .lazyVStack:
//            if let ctor = LazyVStackViewConstructor.from(node).map(ViewConstructor.lazyVStack) {
//                attachConstructor(ctor)
//            }
//        case .circle:
//            if let ctor = CircleViewConstructor.from(node).map(ViewConstructor.circle) {
//                attachConstructor(ctor)
//            }
//        case .ellipse:
//            if let ctor = EllipseViewConstructor.from(node).map(ViewConstructor.ellipse) {
//                attachConstructor(ctor)
//            }
//        case .rectangle:
//            if let ctor = RectangleViewConstructor.from(node).map(ViewConstructor.rectangle) {
//                attachConstructor(ctor)
//            }
//        case .roundedRectangle:
//            if let ctor = RoundedRectangleViewConstructor.from(node).map(ViewConstructor.roundedRectangle) {
//                attachConstructor(ctor)
//            }
//        case .zStack:
//            if let ctor = ZStackViewConstructor.from(node).map(ViewConstructor.zStack) {
//                attachConstructor(ctor)
//            }
//        case .textField:
//            if let ctor = TextFieldViewConstructor.from(node).map(ViewConstructor.textField) {
//                attachConstructor(ctor)
//            }
//        case .angularGradient:
//            if let ctor = AngularGradientViewConstructor.from(node).map(ViewConstructor.angularGradient) {
//                attachConstructor(ctor)
//            }
//        case .linearGradient:
//            if let ctor = LinearGradientViewConstructor.from(node).map(ViewConstructor.linearGradient) {
//                attachConstructor(ctor)
//            }
//        case .radialGradient:
//            if let ctor = RadialGradientViewConstructor.from(node).map(ViewConstructor.radialGradient) {
//                attachConstructor(ctor)
//            }
  
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
        
        return [.init(input: .text, value: value)]
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
                      value: portValue)
            ]
            
        case .sfSymbol(let arg):
            guard let portValue = try arg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            return [
                .init(input: .sfSymbol,
                      value: portValue)
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
                              value: value))
        }
        
        if let spacingArg = spacingArg {
            guard let value = try spacingArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            
            list.append(.init(input: .spacing,
                              value: value))
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
            list.append(.init(input: .layerGroupAlignment, value: value))
        }

        // --- spacing (CGFloat?) → .spacing ---
        if let spacingArg = spacingArg {
            guard let value = try spacingArg.derivePortValues().first else {
                throw SwiftUISyntaxError.portValueNotFound
            }
            list.append(.init(input: .spacing, value: value))
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
                list.append(.init(input: .layerGroupAlignment, value: value))
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
//// MARK: - ScrollView -------------------------------------------------------

//
//// TODO: NOT USED ATM
//enum ScrollViewViewConstructor: Equatable, FromSwiftUIViewToStitch {
//    /// ScrollView(axes:showIndicators:)
//    //    case parameters(axes: Parameter<Axis.Set> = .literal(.vertical),
//    //                    showsIndicators: Parameter<Bool> = .literal(true))
//
//    case parameters(axes: SyntaxViewModifierArgumentType?,
//                    showsIndicators: SyntaxViewModifierArgumentType?)
//
//    // Will this now always produce a group?
//    var layer: AIGraphData_V0.Layer { .group }
//
//    // MARK: Stitch mapping
//    ///
//    /// • Always returns `(.scroll, …)`
//    /// • `.horizontal`   →  scrollXEnabled = true
//    /// • `.vertical`     →  scrollYEnabled = true   (default if no arg)
//    /// • `[.horizontal, .vertical]` or `.all`
//    ///                    →  both scrollXEnabled & scrollYEnabled = true
//    /// • Any expression  →  single `.edge(expr)` (caller decides)
//    //    var toStitch: (Layer?, [ValueOrEdge])? {
//    //        guard case let .parameters(axes, _) = self else { return nil }
//    //        var list: [ValueOrEdge] = []
//    //
//    //        switch axes {
//    //        case .literal(let set):
//    //            // Axis.Set is an OptionSet; test for membership.
//    //            if set.contains(.horizontal) {
//    //                list.append(.value(.init(.scrollXEnabled, .bool(true))))
//    //            }
//    //            if set.contains(.vertical) {
//    //                list.append(.value(.init(.scrollYEnabled, .bool(true))))
//    //            }
//    //            if set == [.horizontal, .vertical] {
//    //                // Already handled by the contains checks, nothing extra
//    //            }
//    //            // If neither bit is set (shouldn’t happen), default to vertical
//    //            if list.isEmpty {
//    //                list.append(.value(.init(.scrollYEnabled, .bool(true))))
//    //            }
//    //
//    //        case .expression(let expr):
//    //            // Try to evaluate at compile‑time
//    //            if let litSet = expr.axisSetLiteral() {
//    //                if litSet.contains(.horizontal) {
//    //                    list.append(.value(.init(.scrollXEnabled, .bool(true))))
//    //                }
//    //                if litSet.contains(.vertical) || litSet.isEmpty {
//    //                    list.append(.value(.init(.scrollYEnabled, .bool(true))))
//    //                }
//    //            } else {
//    //                // Unresolved at compile‑time → forward as edge
//    //                list.append(.edge(expr))
//    //            }
//    //        }
//    //
//    //        return (
//    //            nil, // ScrollView does not technically correspond to a Stitch Layer
//    //            list
//    //        )
//    //    }
//
//    // MARK: - ScrollView createCustomValueEvents
//    ///
//    /// • Enables scrollX / scrollY as before.
//    /// • Also sets `orientation`:
//    ///     – horizontal-only  → .horizontal
//    ///     – vertical-only *or* both  → .vertical
//    ///
//    func createCustomValueEvents() throws -> [ASTCustomInputValue] {
//        guard case let .parameters(axesArg, _) = self else { return [] }
//
//        func enable(_ port: LayerInputPort) -> ASTCustomInputValue {
//            .init(input: port, value: .bool(true))
//        }
//
//        // ── Default when no `axes:` parameter is supplied
//        if axesArg == nil {
//            return [
//                enable(.scrollYEnabled),
//                .init(input: .orientation,
//                      value: .orientation(.vertical))
//            ]
//        }
//
//        var enableX = false
//        var enableY = false
//
//        switch axesArg! {
//
//        // ----- .horizontal / .vertical / .all ------------------------------
//        case .memberAccess(let ma):
//            switch ma.property {
//            case "horizontal": enableX = true
//            case "vertical":   enableY = true
//            case "all":        enableX = true; enableY = true
//            default:
//                throw SwiftUISyntaxError
//                    .unsupportedConstructorForPortValueDecoding(.scrollView(self))
//            }
//
//        // ----- [.horizontal, .vertical] etc. -------------------------------
//        case .array(let elements):
//            for el in elements {
//                if case let .memberAccess(ma) = el {
//                    switch ma.property {
//                    case "horizontal": enableX = true
//                    case "vertical":   enableY = true
//                    default: break
//                    }
//                }
//            }
//            if !enableX && !enableY {
//                throw SwiftUISyntaxError
//                    .unsupportedConstructorForPortValueDecoding(.scrollView(self))
//            }
//
//        case .complex(let complexType):
//            return try handleComplexArgumentType(
//                complexType,
//                // Not relevant when working with `PortValueDescription` ?
//                context: nil)
//
//            // What does PVD for `[.horizontal, .vertical]` look like? Do we get one PVD, or multiple?
//            // The returned PortValue is just a bool, i.e. not enough to tell us
//            .map { (pv: AIGraphData_V0.PortValueVersion.PortValue) in
//                    // TODO: there's not really a good way to turn
//                    // Can't know
//                    ASTCustomInputValue(input: .scrollYEnabled,
//                                        value: pv)
//                }
//
//        default:
//            throw SwiftUISyntaxError
//                .unsupportedConstructorForPortValueDecoding(.scrollView(self))
//        }
//
//        // Assemble events ---------------------------------------------------
//        var events: [ASTCustomInputValue] = []
//        if enableX { events.append(enable(.scrollXEnabled)) }
//        if enableY { events.append(enable(.scrollYEnabled)) }
//
//        let orientationValue: PortValue = .orientation(
//            (enableX && !enableY) ? .horizontal : .vertical
//        )
//        events.append(.init(input: .orientation, value: orientationValue))
//
//        return events
//    }
//
//    static func from(_ args: [SyntaxViewArgumentData]) -> ScrollViewViewConstructor? {
//        // SwiftUI defaults: vertical scrolling & indicators shown
//        var axes: SyntaxViewModifierArgumentType?
//        var indicators: SyntaxViewModifierArgumentType?
//
//        //        var axes: Parameter<Axis.Set> = .literal(.vertical)
//        //        var indicators: Parameter<Bool> = .literal(true)
//
//        for arg in args {
//            // Identify the parameter by `label`
//            switch arg.label {
//            case nil,            // first unlabeled param is `Axis.Set`
//                "axes":
//                axes = arg.value
//
//            case "showsIndicators":
//                //                if let bool = arg.value.boolLiteral {
//                //                    indicators = .literal(bool)
//                //                }
//                indicators = arg.value
//
//            default:
//                break       // ignore `content:` closure and any unknown labels
//            }
//        }
//
//        return .parameters(axes: axes, showsIndicators: indicators)
//    }
//
//}



//
//
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
