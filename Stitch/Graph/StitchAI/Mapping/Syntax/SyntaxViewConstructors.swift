//
//  SyntaxViewConstructors.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/9/25.
//



import Foundation
import SwiftUI
import UIKit
import NonEmpty
import StitchSchemaKit



// MARK: - Parameter wrapper: literal vs. arbitrary expression ---------

/// A constructor argument that was either a compile‑time literal (`"logo"`,
/// `.center`, `12`) or an arbitrary Swift expression (`myGap`, `foo()`, etc.).
enum Parameter<Value: Equatable>: Equatable {
    case literal(Value)
    case expression(ExprSyntax)

    /// Convenience for pattern‑matching in `toStitch`.
    var literal: Value? {
        if case .literal(let v) = self { return v }
        return nil
    }
}


enum ValueOrEdge: Equatable {
    case value(CustomInputValue)
    case edge(ExprSyntax)
}

struct CustomInputValue: Equatable, Hashable {
    let input: LayerInputPort
    let value: PortValue
    
    init(_ input: LayerInputPort,  _ value: PortValue) {
        self.input = input
        self.value = value
    }
}


protocol FromSwiftUIViewToStitch {
    associatedtype T
    
    var toStitch: (Layer, [ValueOrEdge])? { get }
    
    static func from(_ node: FunctionCallExprSyntax) -> T?
}


extension ViewConstructor {
    
    func getCustomValueEvents(id: UUID) -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]? {
        
        guard let toStitchResult = self.toStitch else {
            return nil
        }
        
        let inputs = toStitchResult.1
        
        return inputs.compactMap { (valueOrEdge: ValueOrEdge) in
            switch valueOrEdge {
            case .edge:
                return nil
            case .value(let x):
                if let downgradedInput = try? x.input.convert(to: CurrentStep.LayerInputPort.self),
                   let downgradedValue = try? x.value.convert(to: CurrentStep.PortValue.self) {
                    return CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue.init(
                        id: id,
                        input: downgradedInput,
                        value: downgradedValue)
                } else {
                    return nil
                }
            }
        }
        
    }
}


// TODO: use a protocol instead ?
enum ViewConstructor: Equatable {
    case text(TextViewConstructor)
    case image(ImageViewConstructor)
    case hStack(HStackViewConstructor)
    case vStack(VStackViewConstructor)
    case lazyHStack(LazyHStackViewConstructor)
    case lazyVStack(LazyVStackViewConstructor)
    case circle(CircleViewConstructor)
    case ellipse(EllipseViewConstructor)
    case rectangle(RectangleViewConstructor)
    case roundedRectangle(RoundedRectangleViewConstructor)
    case scrollView(ScrollViewViewConstructor)
    case zStack(ZStackViewConstructor)
    case textField(TextFieldViewConstructor)
    case angularGradient(AngularGradientViewConstructor)
    case linearGradient(LinearGradientViewConstructor)
    case radialGradient(RadialGradientViewConstructor)
    
    var toStitch: (Layer, [ValueOrEdge])? {
        switch self {
        case .text(let c):             return c.toStitch
        case .image(let c):            return c.toStitch
        case .hStack(let c):           return c.toStitch
        case .vStack(let c):           return c.toStitch
        case .lazyHStack(let c):       return c.toStitch
        case .lazyVStack(let c):       return c.toStitch
        case .circle(let c):           return c.toStitch
        case .ellipse(let c):          return c.toStitch
        case .rectangle(let c):        return c.toStitch
        case .roundedRectangle(let c): return c.toStitch
        case .scrollView(let c):       return c.toStitch
        case .zStack(let c):           return c.toStitch
        case .textField(let c):        return c.toStitch
        case .angularGradient(let c):  return c.toStitch
        case .linearGradient(let c):   return c.toStitch
        case .radialGradient(let c):   return c.toStitch
        }
    }
}
    

enum TextViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// `Text("Hello")`
    case string(_ content: Parameter<String>)
    
    /// `Text(_ key: LocalizedStringKey)`
    case localized(_ key: Parameter<LocalizedStringKey>)
    
    /// `Text(verbatim: "Raw")`
    case verbatim(_ content: Parameter<String>)
    
    /// `Text(_ attributed: AttributedString)`
    case attributed(_ content: Parameter<AttributedString>)

    var toStitch: (Layer, [ValueOrEdge])? {
        switch self {

        case .string(let p), .verbatim(let p):
            switch p {
            case .literal(let s):
                return (.text,
                        [ .value(.init(.text, .string(.init(s)))) ])
            case .expression(let expr):
                return (.text,
                        [ .edge(expr) ])
            }

        case .localized(let p):
            switch p {
            case .literal(let key):
                return (.text,
                        [ .value(.init(.text,
                                       .string(.init(key.resolved)))) ])
            case .expression(let expr):
                return (.text, [ .edge(expr) ])
            }

        case .attributed(let p):
            switch p {
            case .literal(let attr):
                return (.text,
                        [ .value(.init(.text,
                                       .string(.init(attr.plainText)))) ])
            case .expression(let expr):
                return (.text, [ .edge(expr) ])
            }
        }
    }

    // Factory that infers the correct overload from a `FunctionCallExprSyntax`
    static func from(_ node: FunctionCallExprSyntax) -> TextViewConstructor? {
        let args = node.arguments

        // 1. Text("Hello")
        if args.count == 1, args.first!.label == nil,
           let lit = args.first!.expression.as(StringLiteralExprSyntax.self) {
            return .string(.literal(lit.decoded()))
        }

        // 2. Text(verbatim: "Raw")
        if let first = args.first,
           first.label?.text == "verbatim",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            return .verbatim(.literal(lit.decoded()))
        }

        // 3. Text(LocalizedStringKey("key"))
        if args.count == 1,
           args.first!.label == nil,
           let call = args.first!.expression.as(FunctionCallExprSyntax.self),
           let id = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
           id == "LocalizedStringKey",
           let lit = call.arguments.first?.expression.as(StringLiteralExprSyntax.self) {
            return .localized(.literal(LocalizedStringKey(lit.decoded())))
        }

        // 4. Text(AttributedString("Fancy"))
        if args.count == 1,
           args.first!.label == nil,
           let call = args.first!.expression.as(FunctionCallExprSyntax.self),
           let id = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
           id == "AttributedString",
           let lit = call.arguments.first?.expression.as(StringLiteralExprSyntax.self) {
            return .attributed(.literal(AttributedString(lit.decoded())))
        }

        // If it's some other expression like Text(title)
        return .string(.expression(args.first!.expression))
    }
}


enum ImageViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// `Image("assetName", bundle: nil)`
    case asset(name: Parameter<String>, bundle: Parameter<Bundle?> = .literal(nil))
    /// `Image(systemName: "gear")`
    case sfSymbol(name: Parameter<String>)
    /// `Image(decorative:name:bundle:)`
    case decorative(name: Parameter<String>, bundle: Parameter<Bundle?> = .literal(nil))
    /// `Image(uiImage:)`
    case uiImage(image: Parameter<UIImage>)

    var toStitch: (Layer, [ValueOrEdge])? {
        switch self {

        case .asset(let name, _),
             .decorative(let name, _):
            switch name {
            case .literal(let lit):
                return (.image,
                        [ .value(.init(.image, .string(.init(lit)))) ])
            case .expression(let expr):
                return (.image, [ .edge(expr) ])
            }

        case .sfSymbol(let name):
            switch name {
            case .literal(let lit):
                return (.image,
                        [ .value(.init(.sfSymbol, .string(.init(lit)))) ])
            case .expression(let expr):
                return (.image, [ .edge(expr) ])
            }

        case .uiImage(let image):
            switch image {
            case .literal(let ui):
                return (.image,
                        [ .value(.init(.image, .asyncMedia(nil))) ])
            case .expression(let expr):
                return (.image, [ .edge(expr) ])
            }
        }
    }

    // Factory that infers the correct overload from a `FunctionCallExprSyntax`
    static func from(_ node: FunctionCallExprSyntax) -> ImageViewConstructor? {
        let args = node.arguments
        guard let first = args.first else { return nil }

        // 1. Image(systemName:)
        if first.label?.text == "systemName" {
            return .sfSymbol(name: first.asParameterString())
        }

        // 2. Image("asset"[, bundle:])
        if first.label == nil {
            let bundle: Parameter<Bundle?> = .literal(nil)
            return .asset(name: first.asParameterString(), bundle: bundle)
        }

        // 3. Image(decorative: "name"[, bundle:])
        if first.label?.text == "decorative" {
            let bundle: Parameter<Bundle?> = .literal(nil)
            return .decorative(name: first.asParameterString(), bundle: bundle)
        }

        // 4. Image(uiImage:)
        if first.label?.text == "uiImage" {
            return .uiImage(image: .expression(first.expression))
        }

        return nil
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
    case parameters(alignment: Parameter<VerticalAlignment> = .literal(.center),
                    spacing:   Parameter<CGFloat?>          = .literal(nil))

    // MARK: Stitch mapping
    var toStitch: (Layer, [ValueOrEdge])? {
        var list: [ValueOrEdge] = [
            .value(.init(.orientation, .orientation(.horizontal)))
        ]

        guard case let .parameters(alignment, spacing) = self else { return nil }

        // Alignment
        switch alignment {
        case .literal(let a) where a != .center:
            list.append(.value(.init(.layerGroupAlignment,
                                     // TODO: if `a.toAnchoring` fails, return `SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)` ?
                                     .anchoring(a.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        default: break
        }

        // Spacing
        switch spacing {
        case .literal(let s?) :
            list.append(.value(.init(.spacing, .spacing(.number(s)))))
        case .expression(let expr):
            list.append(.edge(expr))
        default: break
        }

        return (.group, list)
    }

    // MARK: Parse from SwiftSyntax
    static func from(_ node: FunctionCallExprSyntax) -> HStackViewConstructor? {
        let args = node.arguments

        // defaults
        var alignment: Parameter<VerticalAlignment> = .literal(.center)
        var spacing:   Parameter<CGFloat?>          = .literal(nil)

        // iterate through labelled args
        for arg in args {
            switch arg.label?.text {
            case "alignment":
                if let lit = arg.vertAlignLiteral {
                    alignment = .literal(lit)
                } else {
                    alignment = .expression(arg.expression)
                }
            case "spacing":
                if let num = arg.cgFloatValue {
                    spacing = .literal(num)
                } else {
                    spacing = .expression(arg.expression)
                }
            default:
                // ignore other labels (content closure etc.)
                break
            }
        }

        return .parameters(alignment: alignment, spacing: spacing)
    }
}

// TODO: a lot of this logic overlaps with HStackViewConstructor; only difference is `HorizontalAlignment` instead of `VerticalAlignment`
enum VStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI exposes just one public initializer:
    /// `init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)`
    case parameters(alignment: Parameter<HorizontalAlignment> = .literal(.center),
                    spacing:   Parameter<CGFloat?>            = .literal(nil))

    // MARK: Stitch mapping
    var toStitch: (Layer, [ValueOrEdge])? {
        var list: [ValueOrEdge] = [
            .value(.init(.orientation, .orientation(.vertical)))
        ]

        guard case let .parameters(alignment, spacing) = self else { return nil }

        switch alignment {
        case .literal(let a) where a != .center:
            list.append(.value(.init(.layerGroupAlignment,
                                     .anchoring(a.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        default: break
        }

        switch spacing {
        case .literal(let s?):
            list.append(.value(.init(.spacing, .spacing(.number(s)))))
        case .expression(let expr):
            list.append(.edge(expr))
        default: break
        }

        return (.group, list)
    }

    // MARK: Parse from SwiftSyntax
    static func from(_ node: FunctionCallExprSyntax) -> VStackViewConstructor? {
        let args = node.arguments
        var alignment: Parameter<HorizontalAlignment> = .literal(.center)
        var spacing:   Parameter<CGFloat?>            = .literal(nil)

        for arg in args {
            switch arg.label?.text {
            case "alignment":
                if let lit = arg.horizAlignLiteral {
                    alignment = .literal(lit)
                } else {
                    alignment = .expression(arg.expression)
                }
            case "spacing":
                if let num = arg.cgFloatValue {
                    spacing = .literal(num)
                } else {
                    spacing = .expression(arg.expression)
                }
            default:
                break
            }
        }

        return .parameters(alignment: alignment, spacing: spacing)
    }
}

// ── Helper: random-access a TupleExprElementListSyntax by Int index ────────────
extension LabeledExprListSyntax {
    subscript(safe index: Int) -> LabeledExprSyntax? {
        guard index >= 0 && index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }
}

enum LazyHStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case parameters(alignment: Parameter<VerticalAlignment> = .literal(.center),
                    spacing:   Parameter<CGFloat?>          = .literal(nil))

    var toStitch: (Layer, [ValueOrEdge])? {
        switch self {
        case .parameters(let alignment, let spacing):
            return HStackViewConstructor
                .parameters(alignment: alignment, spacing: spacing)
                .toStitch
        }
    }

    static func from(_ node: FunctionCallExprSyntax) -> LazyHStackViewConstructor? {
        // Re‑use HStack parser then wrap
        guard let base = HStackViewConstructor.from(node) else { return nil }
        switch base {
        case .parameters(let a, let s): return .parameters(alignment: a, spacing: s)
        }
    }
}

enum LazyVStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case parameters(alignment: Parameter<HorizontalAlignment> = .literal(.center),
                    spacing:   Parameter<CGFloat?>            = .literal(nil))

    var toStitch: (Layer, [ValueOrEdge])? {
        switch self {
        case .parameters(let alignment, let spacing):
            return VStackViewConstructor
                .parameters(alignment: alignment, spacing: spacing)
                .toStitch
        }
    }

    static func from(_ node: FunctionCallExprSyntax) -> LazyVStackViewConstructor? {
        guard let base = VStackViewConstructor.from(node) else { return nil }
        switch base {
        case .parameters(let a, let s): return .parameters(alignment: a, spacing: s)
        }
    }
}

// MARK: - ZStack -----------------------------------------------------------

// MARK: - TextField --------------------------------------------------------

enum TextFieldViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// Simplified model:
    /// `TextField(_ titleKey: LocalizedStringKey, text: Binding<String>)`
    /// or `TextField(_ title: String, text: Binding<String>)`
    case parameters(title: Parameter<String?> = .literal(nil),
                    binding: ExprSyntax)          // always an expression edge

    // MARK: Stitch mapping
    ///
    /// • `title`  →  .placeholder   (omit if nil)
    /// • `binding`→  .text          (literal constant → value, otherwise edge)
    var toStitch: (Layer, [ValueOrEdge])? {
        guard case let .parameters(title, bindingExpr) = self else { return nil }
        var list: [ValueOrEdge] = []
        
        // ----- title / placeholder ---------------------------------------
        switch title {
        case .literal(let str?):
            list.append(.value(.init(.placeholderText,
                                     .string(.init(str)))))
        case .expression(let expr):
            list.append(.edge(expr))
        default:
            break    // .literal(nil)  → no placeholder
        }
        
        // ----- binding / text -------------------------------------------
        if let constLiteral = bindingExpr.stringLiteralFromConstantBinding() {
            list.append(.value(.init(.text,
                                     .string(.init(constLiteral)))))
        } else {
            list.append(.edge(bindingExpr))
        }
        
        return (.textField, list)
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        let args = node.arguments

        // need at least title + binding
        guard let first = args[safe: 0],
              let second = args[safe: 1] else { return nil }

        // First argument can be unlabeled placeholder string/localised key
        var title: Parameter<String?> = .literal(nil)
        if first.label == nil,
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            title = .literal(lit.decoded())
        } else if first.label == nil {
            title = .expression(first.expression)
        }

        // Second arg must be `text:` binding
        guard second.label?.text == "text" else { return nil }

        return .parameters(title: title,
                           binding: second.expression)
    }
}

enum ZStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// SwiftUI: `init(alignment: Alignment = .center, content:)`
    case parameters(alignment: Parameter<Alignment> = .literal(.center))

    // Orientation is implicit overlap; we won’t emit orientation value.
    var toStitch: (Layer, [ValueOrEdge])? {
        var list: [ValueOrEdge] = []

        guard case let .parameters(alignment) = self else { return nil }

        switch alignment {
        case .literal(let a) where a != .center:
            list.append(.value(.init(.layerGroupAlignment,
                                     .anchoring(a.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        default:
            break
        }

        return (.group, list)
    }

    static func from(_ node: FunctionCallExprSyntax) -> ZStackViewConstructor? {
        var alignment: Parameter<Alignment> = .literal(.center)

        for arg in node.arguments {
            if arg.label?.text == "alignment" {
                if let alignLit = arg.alignmentLiteral {
                    alignment = .literal(alignLit)
                } else {
                    alignment = .expression(arg.expression)
                }
            }
        }

        return .parameters(alignment: alignment)
    }
}

// MARK: - Circle & Rectangle (no‑arg views) -------------------------------

enum CircleViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                                    // Circle()

    var toStitch: (Layer, [ValueOrEdge])? {
        (.oval, [])                             // no args, nothing to edge
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        node.arguments.isEmpty ? .plain : nil
    }
}

enum EllipseViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                                  // Ellipse()

    var toStitch: (Layer, [ValueOrEdge])? {
        (.oval, [])                             // same mapping as Circle
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        node.arguments.isEmpty ? .plain : nil
    }
}

enum RectangleViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                                    // Rectangle()

    var toStitch: (Layer, [ValueOrEdge])? {
        (.rectangle, [])                          // no args
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        node.arguments.isEmpty ? .plain : nil
    }
}

// MARK: - RoundedRectangle -------------------------------------------------

enum RoundedRectangleViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// RoundedRectangle(cornerRadius:style:)
    case cornerRadius(radius: Parameter<CGFloat>,
                      style:  Parameter<RoundedCornerStyle> = .literal(.continuous))
    
    /// RoundedRectangle(cornerSize:style:)
    case cornerSize(size: Parameter<CGSize>,
                    style: Parameter<RoundedCornerStyle> = .literal(.continuous))
    
    // MARK: Stitch mapping
    ///
    /// • RoundedRectangle(cornerRadius:) → Layer.rectangle + cornerRadius
    /// • RoundedRectangle(cornerSize:)   → Layer.rectangle + cornerSize
    ///
    /// (We ignore the `style` for now; it can be added later.)
    var toStitch: (Layer, [ValueOrEdge])? {
        switch self
        {
        // ── cornerRadius(radius:style:) ───────────────────────────────
        case .cornerRadius(let radius, _):
            switch radius {
            case .literal(let r):
                return (
                    .rectangle,
                    [ .value(.init(.cornerRadius, .number(r))) ]
                )
            case .expression(let expr):
                return (
                    .rectangle,
                    [ .edge(expr) ]
                )
            }

        // ── cornerSize(size:style:) ───────────────────────────────────
        case .cornerSize(let size, _):
            switch size {
            case .literal(let s):
                return (
                    .rectangle,
//                    [ .value(.init(.cornerSize, .size(s))) ]
                    [ .value(.init(.cornerRadius, .number(s.width))) ]
                )
            case .expression(let expr):
                return (
                    .rectangle,
                    [ .edge(expr) ]
                )
            }
        }
    }
    
    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        let args = node.arguments
        guard let first = args.first else { return nil }
        
        if first.label?.text == "cornerRadius" {
            let style: Parameter<RoundedCornerStyle> = .literal(.continuous)
            return .cornerRadius(radius: first.asParameterCGFloat(), style: style)
        }
        if first.label?.text == "cornerSize" {
            let style: Parameter<RoundedCornerStyle> = .literal(.continuous)
            return .cornerSize(size: first.asParameterCGSize(), style: style)
        }
        return nil
    }
}

// MARK: - ScrollView -------------------------------------------------------

enum ScrollViewViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// ScrollView(axes:showIndicators:)
    case parameters(axes: Parameter<Axis.Set> = .literal(.vertical),
                    showsIndicators: Parameter<Bool> = .literal(true))
    
    // Placeholder – mapping not yet defined
    var toStitch: (Layer, [ValueOrEdge])? { nil }
    
    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        let args = node.arguments
        var axes: Parameter<Axis.Set> = .literal(.vertical)
        var indicators: Parameter<Bool> = .literal(true)
        
        for arg in args {
            switch arg.label?.text {
            case nil:      // unnamed first parameter can be Axis.Set
                axes = arg.asParameterAxisSet()
            case "showsIndicators":
                indicators = arg.asParameterBool()
            default:
                break
            }
        }
        return .parameters(axes: axes, showsIndicators: indicators)
    }
}

extension Alignment {
    var toAnchoring: Anchoring {
        switch self {
        case .topLeading:     return .topLeft
        case .top:            return .topCenter
        case .topTrailing:    return .topRight
        case .leading:        return .centerLeft
        case .center:         return .centerCenter
        case .trailing:       return .centerRight
        case .bottomLeading:  return .bottomLeft
        case .bottom:         return .bottomCenter
        case .bottomTrailing: return .bottomRight
        default:              return .centerCenter
        }
    }
}


// ── Tiny extraction helpers for alignment / spacing literals ─────────────
extension LabeledExprSyntax {
    var alignmentLiteral: Alignment? {
        if let member = expression.as(MemberAccessExprSyntax.self)?
                .declName.baseName.text {
            switch member {
            case "topLeading":     return .topLeading
            case "top":            return .top
            case "topTrailing":    return .topTrailing
            case "leading":        return .leading
            case "center":         return .center
            case "trailing":       return .trailing
            case "bottomLeading":  return .bottomLeading
            case "bottom":         return .bottom
            case "bottomTrailing": return .bottomTrailing
            default: return nil
            }
        }
        return nil
    }

    var cgFloatValue: CGFloat? {
        if let float = expression.as(FloatLiteralExprSyntax.self) {
            return CGFloat(Double(float.literal.text) ?? 0)
        }
        if let int = expression.as(IntegerLiteralExprSyntax.self) {
            return CGFloat(Double(int.literal.text) ?? 0)
        }
        return nil
    }

    // New helper: vertical alignment literal
    var vertAlignLiteral: VerticalAlignment? {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
                .declName.baseName.text {
            switch ident {
            case "top": return .top
            case "bottom": return .bottom
            case "firstTextBaseline": return .firstTextBaseline
            case "lastTextBaseline": return .lastTextBaseline
            case "center": return .center
            default: return nil
            }
        }
        return nil
    }

    // New helper: horizontal alignment literal
    var horizAlignLiteral: HorizontalAlignment? {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
                .declName.baseName.text {
            switch ident {
            case "leading": return .leading
            case "trailing": return .trailing
            case "center": return .center
            default: return nil
            }
        }
        return nil
    }

    var vertAlignValue: VerticalAlignment {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text
        {
            switch ident {
            case "top":               return .top
            case "bottom":            return .bottom
            case "firstTextBaseline": return .firstTextBaseline
            case "lastTextBaseline":  return .lastTextBaseline
            default:                  return .center
            }
        }
        return .center
    }

    func asParameterString() -> Parameter<String> {
        if let lit = expression.as(StringLiteralExprSyntax.self) {
            return .literal(lit.decoded())
        }
        return .expression(expression)
    }

    func asParameterCGFloat() -> Parameter<CGFloat> {
        if let lit = cgFloatValue {
            return .literal(lit)
        }
        return .expression(expression)
    }

    func asParameterCGSize() -> Parameter<CGSize> {
        if let tuple = expression.as(TupleExprSyntax.self),
           let wLit = tuple.elements.first?.expression.as(FloatLiteralExprSyntax.self),
           let hLit = tuple.elements[safe: 1]?.expression.as(FloatLiteralExprSyntax.self),
           let w = Double(wLit.literal.text),
           let h = Double(hLit.literal.text) {
            return .literal(CGSize(width: w, height: h))
        }
        return .expression(expression)
    }

    func asParameterAxisSet() -> Parameter<Axis.Set> {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text {
            switch ident {
            case "vertical":   return .literal(.vertical)
            case "horizontal": return .literal(.horizontal)
            default: break
            }
        }
        return .expression(expression)
    }

    func asParameterBool() -> Parameter<Bool> {
        if let bool = expression.as(BooleanLiteralExprSyntax.self) {
            return .literal(bool.literal.text == "true")
        }
        return .expression(expression)
    }
}

extension Parameter where Value: CustomStringConvertible {
    /// Fragment suitable for regenerating Swift source.
    var swiftFragment: String {
        switch self {
        case .literal(let v):    return String(describing: v)
        case .expression(let e): return e.description
        }
    }
}

private extension ExprSyntax {
    /// If this expression is `.constant("string")` return the literal string.
    /// Otherwise return `nil`.
    func stringLiteralFromConstantBinding() -> String? {
        guard
            let call = self.as(FunctionCallExprSyntax.self),
            let baseName = call.calledExpression.as(MemberAccessExprSyntax.self)?
                             .declName.baseName.text ?? call.calledExpression
                             .as(DeclReferenceExprSyntax.self)?
                             .baseName.text,
            baseName == "constant",
            let first = call.arguments.first,
            let lit   = first.expression.as(StringLiteralExprSyntax.self)
        else { return nil }
        
        return lit.decoded()
    }
}



// MARK: - Proof‑of‑Concept Visitor ----------------------------------------
//
//  This visitor is *stand-alone* and confined to this file so you can
//  experiment without touching the real parsing pipeline elsewhere.
//
import SwiftSyntax
import SwiftParser

/// A lightweight record of each Text / Image call we find.
struct POCViewCall {
    enum Kind {
        case text(TextViewConstructor)
        case image(ImageViewConstructor)
        case hStack(HStackViewConstructor)
        case vStack(VStackViewConstructor)
        case lazyHStack(LazyHStackViewConstructor)
        case lazyVStack(LazyVStackViewConstructor)
        case circle(CircleViewConstructor)
        case ellipse(EllipseViewConstructor)
        case rectangle(RectangleViewConstructor)
        case roundedRectangle(RoundedRectangleViewConstructor)
        case scrollView(ScrollViewViewConstructor)
        case zStack(ZStackViewConstructor)
        case textField(TextFieldViewConstructor)
        case angularGradient(AngularGradientViewConstructor)
        case linearGradient(LinearGradientViewConstructor)
        case radialGradient(RadialGradientViewConstructor)
    }
    let kind: Kind
    let node: FunctionCallExprSyntax       // handy for debugging / source‑ranges
}

/// Walks any Swift source and classifies Text / Image constructors
/// into the strongly‑typed enums defined above.
final class POCConstructorVisitor: SyntaxVisitor {

    private(set) var calls: [POCViewCall] = []

    // We only care about function calls.
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {

        guard let calleeIdent = node.calledExpression.as(DeclReferenceExprSyntax.self)?
            .baseName.text
        else { return .skipChildren }
        
        print("POCVisitor: visiting \(calleeIdent) – args: \(node.arguments.count)")

        switch calleeIdent {

        case "Text":
            if let ctor = TextViewConstructor.from(node) {
                calls.append(.init(kind: .text(ctor), node: node))
            }

        case "Image":
            if let ctor = ImageViewConstructor.from(node) {
                calls.append(.init(kind: .image(ctor), node: node))
            }

        case "HStack":
            if let ctor = HStackViewConstructor.from(node) {
                calls.append(.init(kind: .hStack(ctor), node: node))
            }

        case "VStack":
            if let ctor = VStackViewConstructor.from(node) {
                calls.append(.init(kind: .vStack(ctor), node: node))
            }

        case "LazyHStack":
            if let ctor = LazyHStackViewConstructor.from(node) {
                calls.append(.init(kind: .lazyHStack(ctor), node: node))
            }

        case "LazyVStack":
            if let ctor = LazyVStackViewConstructor.from(node) {
                calls.append(.init(kind: .lazyVStack(ctor), node: node))
            }

        case "Circle":
            if let ctor = CircleViewConstructor.from(node) {
                calls.append(.init(kind: .circle(ctor), node: node))
            }

        case "Ellipse":
            if let ctor = EllipseViewConstructor.from(node) {
                calls.append(.init(kind: .ellipse(ctor), node: node))
            }

        case "Rectangle":
            if let ctor = RectangleViewConstructor.from(node) {
                calls.append(.init(kind: .rectangle(ctor), node: node))
            }

        case "RoundedRectangle":
            if let ctor = RoundedRectangleViewConstructor.from(node) {
                calls.append(.init(kind: .roundedRectangle(ctor), node: node))
            }

        case "ScrollView":
            if let ctor = ScrollViewViewConstructor.from(node) {
                calls.append(.init(kind: .scrollView(ctor), node: node))
            }

        case "ZStack":
            if let ctor = ZStackViewConstructor.from(node) {
                calls.append(.init(kind: .zStack(ctor), node: node))
            }

        case "TextField":
            if let ctor = TextFieldViewConstructor.from(node) {
                calls.append(.init(kind: .textField(ctor), node: node))
            }

        case "AngularGradient":
            if let ctor = AngularGradientViewConstructor.from(node) {
                calls.append(.init(kind: .angularGradient(ctor), node: node))
            }
        case "LinearGradient":
            if let ctor = LinearGradientViewConstructor.from(node) {
                calls.append(.init(kind: .linearGradient(ctor), node: node))
            }
        case "RadialGradient":
            if let ctor = RadialGradientViewConstructor.from(node) {
                calls.append(.init(kind: .radialGradient(ctor), node: node))
            }

        default:
            break
        }
        return .visitChildren
    }
}

// MARK: - Tiny helpers -----------------------------------------------------

extension StringLiteralExprSyntax {
    /// Returns the runtime value of a simple one‑segment string literal.
    func decoded() -> String {
        guard case .stringSegment(let seg)? = segments.first else { return description }
        // remove the surrounding quotes and unescape \" \\ \n \t
        return seg.content.text
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\\n"#, with: "\n")
            .replacingOccurrences(of: #"\\t"#, with: "\t")
            .replacingOccurrences(of: #"\\\\"#, with: "\\")
    }
}

// MARK: - SwiftUI Preview --------------------------------------------------

import SwiftUI

/// A quick SwiftUI preview that shows how the proof‑of‑concept visitor
/// classifies a handful of Text / Image constructor calls.
struct ConstructorDemoView: View {
    
    static let sampleSource = """
        Text("Hello")
        Text(verbatim: "Raw verbatim value")
        Text(LocalizedStringKey("greeting_key"))
        Text(AttributedString("Fancy attributed"))

        Image(systemName: "gear")
        Image("logo")
        Image("photo", bundle: .main)
        Image(decorative: "decor", bundle: nil)

        HStack
        HStack(alignment: .top)
        HStack(spacing: 20)
        HStack(alignment: .bottom, spacing: 10)

        VStack // { Text("B") }
        VStack(alignment: .leading) // { Text("B") }
        VStack(spacing: 12) // { Text("B") }
        VStack(alignment: .trailing, spacing: 6) // { Text("B") }

        LazyHStack
        LazyHStack(alignment: .top)
        LazyHStack(spacing: 8)

        LazyVStack // { Text("D") }
        LazyVStack(alignment: .leading)
        LazyVStack(spacing: 4)
        LazyVStack(spacing: mySpacingVariable)
        LazyVStack(spacing: 2 + 6)
        Circle()
        Ellipse()
        Rectangle()
        RoundedRectangle(cornerRadius: 12)
        ScrollView(.horizontal, showsIndicators: false)
        ZStack
        ZStack(alignment: .topLeading)
        TextField("Email", text: emailBinding)
        AngularGradient(colors: [.red, .blue],
                        center: .center,
                        angle: .degrees(0))
        LinearGradient(colors: [.green, .yellow],
                       startPoint: .leading,
                       endPoint: .trailing)
        RadialGradient(colors: [.purple, .pink],
                       center: .center,
                       startRadius: 0,
                       endRadius: 100)
    """

    // One row of the demo table
    struct DemoRow: Identifiable {
        let id = UUID()
        let code: String
        let overload: String
        let stitch: String
    }

    var rows: [DemoRow] {
        let tree = Parser.parse(source: Self.sampleSource)
        let visitor = POCConstructorVisitor(viewMode: .fixedUp)
        visitor.walk(tree)

        return visitor.calls.map { call in
            let code = call.node.description.trimmingCharacters(in: .whitespacesAndNewlines)

            let overload: String
            let stitch: String

            let (prefix, ctor): (String, any FromSwiftUIViewToStitch)

            switch call.kind {
            case .text(let c):
                (prefix, ctor) = ("Text", c)
            case .image(let c):
                (prefix, ctor) = ("Image", c)
            case .hStack(let c):
                (prefix, ctor) = ("HStack", c)
            case .vStack(let c):
                (prefix, ctor) = ("VStack", c)
            case .lazyHStack(let c):
                (prefix, ctor) = ("LazyHStack", c)
            case .lazyVStack(let c):
                (prefix, ctor) = ("LazyVStack", c)
            case .circle(let c):
                (prefix, ctor) = ("Circle", c)
            case .ellipse(let c):
                (prefix, ctor) = ("Ellipse", c)
            case .rectangle(let c):
                (prefix, ctor) = ("Rectangle", c)
            case .roundedRectangle(let c):
                (prefix, ctor) = ("RoundedRectangle", c)
            case .scrollView(let c):
                (prefix, ctor) = ("ScrollView", c)
            case .zStack(let c):
                (prefix, ctor) = ("ZStack", c)
            case .textField(let c):
                (prefix, ctor) = ("TextField", c)
            case .angularGradient(let c):
                (prefix, ctor) = ("AngularGradient", c)
            case .linearGradient(let c):
                (prefix, ctor) = ("LinearGradient", c)
            case .radialGradient(let c):
                (prefix, ctor) = ("RadialGradient", c)
            }

            overload = "\(prefix).\(ctor)"
            if let (layer, values) = ctor.toStitch {
                let detail = values
                    .map { ve -> String in
                        switch ve {
                        case .value(let cv):
                            return "\(cv.input)=\(cv.value.display)"
                        case .edge(let expr):
                            return "edge<\(expr.description)>"
                        }
                    }
                    .joined(separator: ", ")
                stitch = "Layer: \(layer)  { \(detail) }"
            } else {
                stitch = "—"
            }

            return DemoRow(code: code, overload: overload, stitch: stitch)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("SwiftUI → Overload → Stitch mapping")
                .font(.headline)
                .padding(.bottom, 4)

            List(rows) { row in
                logInView("ConstructorDemoView: row: \(row)")
                HStack(alignment: .top, spacing: 8) {
                    Text(row.code)
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Text(row.overload)
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Text(row.stitch)
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .border(.red, width: 4)
    }
}


// MARK: - Gradients --------------------------------------------------------

enum AngularGradientViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// AngularGradient(colors:center:startAngle:endAngle:)
    case parameters(colors: Parameter<[Color]>,
                    center: Parameter<UnitPoint>,
                    startAngle: Parameter<CGFloat>,
                    endAngle:   Parameter<CGFloat>)
    
    // MARK: Stitch mapping
    ///
    /// SwiftUI                      → Stitch
    /// ---------------------------------------------------------
    /// colors[0]                    → .startColor
    /// colors[1]                    → .endColor
    /// center                       → .centerAnchor
    /// startAngle                   → .startAngle
    /// endAngle                     → .endAngle
    var toStitch: (Layer, [ValueOrEdge])? {
        guard case let .parameters(colors, center, startAngle, endAngle) = self else { return nil }
        var list: [ValueOrEdge] = []
        
        // ----- colors ---------------------------------------------------
        switch colors {
        case .literal(let arr) where arr.count >= 2:
            list.append(.value(.init(.startColor, .color(.init(arr[0])))))
            list.append(.value(.init(.endColor,   .color(.init(arr[1])))))
        case .expression(let expr):
            list.append(.edge(expr))        // expression supplies [Color]
        default:
            break
        }
        
        // ----- center / centerAnchor -----------------------------------
        switch center {
        case .literal(let p):
            list.append(.value(.init(.centerAnchor, .anchoring(p.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        }
        
        // ----- startAngle ----------------------------------------------
        switch startAngle {
        case .literal(let deg):
            list.append(.value(.init(.startAngle, .number(deg))))
        case .expression(let expr):
            list.append(.edge(expr))
        }
        
        // ----- endAngle -------------------------------------------------
        switch endAngle {
        case .literal(let deg):
            list.append(.value(.init(.endAngle, .number(deg))))
        case .expression(let expr):
            list.append(.edge(expr))
        }
        
        return (.angularGradient, list)
    }
    
    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        let args = node.arguments
        guard let colorsArg = args[safe: 0],
              let centerArg = args[safe: 1],
              let startArg  = args[safe: 2],
              let endArg    = args[safe: 3] else { return nil }

        // colors
        let colors: Parameter<[Color]> = colorsArg.colorArrayLiteral
            .map(Parameter.literal) ?? .expression(colorsArg.expression)

        // center
        let center: Parameter<UnitPoint> = centerArg.unitPointLiteral
            .map(Parameter.literal) ?? .expression(centerArg.expression)

        // angles
        func angleParam(_ a: LabeledExprSyntax) -> Parameter<CGFloat> {
            if let deg = a.angleDegreesLiteral { return .literal(deg) }
            if let num = a.cgFloatValue       { return .literal(num) }
            return .expression(a.expression)
        }

        return .parameters(colors: colors,
                           center: center,
                           startAngle: angleParam(startArg),
                           endAngle:   angleParam(endArg))
    }
}

enum LinearGradientViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// LinearGradient(colors:startPoint:endPoint:)
    case parameters(colors: Parameter<[Color]>,
                    startPoint: Parameter<UnitPoint>,
                    endPoint: Parameter<UnitPoint>)

    // MARK: Stitch mapping
    ///
    /// SwiftUI                      → Stitch
    /// ---------------------------------------------------------
    /// colors[0]                    → .startColor   (Color)
    /// colors[1]                    → .endColor     (Color)
    /// startPoint (UnitPoint)       → .startAnchor  (Anchoring)
    /// endPoint   (UnitPoint)       → .endAnchor    (Anchoring)
    ///
    /// Expression arguments become `.edge(expr)`.
    var toStitch: (Layer, [ValueOrEdge])? {
        guard case let .parameters(colors, startPoint, endPoint) = self else { return nil }
        var list: [ValueOrEdge] = []

        // ---- colors ----------------------------------------------------
        switch colors {
        case .literal(let arr) where arr.count >= 2:
            list.append(.value(.init(.startColor, .color(.init(arr[0])))))
            list.append(.value(.init(.endColor,   .color(.init(arr[1])))))
        case .expression(let expr):
            list.append(.edge(expr))         // upstream produces [Color]
        default:
            break
        }

        // ---- startPoint / startAnchor ---------------------------------
        switch startPoint {
        case .literal(let p):
            list.append(.value(.init(.startAnchor, .anchoring(p.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        }

        // ---- endPoint / endAnchor -------------------------------------
        switch endPoint {
        case .literal(let p):
            list.append(.value(.init(.endAnchor, .anchoring(p.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        }

        return (.linearGradient, list)
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        let args = node.arguments
        guard let colorsArg = args[safe: 0],
              let startArg  = args[safe: 1],
              let endArg    = args[safe: 2] else { return nil }

        // colors
        let colors: Parameter<[Color]> = colorsArg.colorArrayLiteral
            .map(Parameter.literal) ?? .expression(colorsArg.expression)

        // points
        let startPt: Parameter<UnitPoint> = startArg.unitPointLiteral
            .map(Parameter.literal) ?? .expression(startArg.expression)
        let endPt: Parameter<UnitPoint> = endArg.unitPointLiteral
            .map(Parameter.literal) ?? .expression(endArg.expression)

        return .parameters(colors: colors, startPoint: startPt, endPoint: endPt)
    }
}

enum RadialGradientViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// RadialGradient(colors:center:startRadius:endRadius:)
    case parameters(colors: Parameter<[Color]>,
                    center: Parameter<UnitPoint>,
                    startRadius: Parameter<CGFloat>,
                    endRadius: Parameter<CGFloat>)

    // MARK: Stitch mapping
    ///
    ///  SwiftUI            → Stitch
    ///  ---------------------------------------------------------
    ///  center             → .startAnchor          (Anchoring)
    ///  colors[0]          → .startColor           (Color)
    ///  colors[1]          → .endColor             (Color)
    ///  startRadius        → .startRadius          (Number)
    ///  endRadius          → .endRadius            (Number)
    ///
    ///  If any argument is an expression we emit an `.edge(expr)` instead.
    var toStitch: (Layer, [ValueOrEdge])? {
        guard case let .parameters(colors, center, startRadius, endRadius) = self else { return nil }
        var list: [ValueOrEdge] = []

        // -------- colors -------------------------------------------------
        switch colors {
        case .literal(let arr) where arr.count >= 2:
            list.append(.value(.init(.startColor, .color(.init(arr[0])))))
            list.append(.value(.init(.endColor,   .color(.init(arr[1])))))
        case .expression(let expr):
            list.append(.edge(expr))           // upstream node outputs [Color]
        default:
            break
        }

        // -------- center / startAnchor ----------------------------------
        switch center {
        case .literal(let pt):
            list.append(.value(.init(.startAnchor, .anchoring(pt.toAnchoring))))
        case .expression(let expr):
            list.append(.edge(expr))
        }

        // -------- startRadius -------------------------------------------
        switch startRadius {
        case .literal(let r):
            list.append(.value(.init(.startRadius, .number(r))))
        case .expression(let expr):
            list.append(.edge(expr))
        }

        // -------- endRadius ---------------------------------------------
        switch endRadius {
        case .literal(let r):
            list.append(.value(.init(.endRadius, .number(r))))
        case .expression(let expr):
            list.append(.edge(expr))
        }

        return (.radialGradient, list)
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        let args = node.arguments
        guard args.count >= 4 else { return nil }
        let colors: Parameter<[Color]>   = .expression(args[safe: 0]!.expression)
        let center: Parameter<UnitPoint> = .expression(args[safe: 1]!.expression)
        let startR: Parameter<CGFloat>   = .expression(args[safe: 2]!.expression)
        let endR:   Parameter<CGFloat>   = .expression(args[safe: 3]!.expression)
        return .parameters(colors: colors, center: center, startRadius: startR, endRadius: endR)
    }
}
