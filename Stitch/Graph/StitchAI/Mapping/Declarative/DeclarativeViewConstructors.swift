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



protocol FromSwiftUIViewToStitch {
    associatedtype T
    
    // nil if ViewConstructor could not be turned into Stitch concepts
    var toStitch: (
        Layer?, // nil e.g. for ScrollView, which contributes custom-values but not own layer
        [ValueOrEdge]
    )? { get }
    
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


// TODO: can we just the `FromSwiftUIViewToStitch` protocol instead? But tricky, since `FromSwiftUIViewToStitch` has an associated i.e. generic type, which would bubble up elsewhere.
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
    
    var toStitch: (Layer?, [ValueOrEdge])? {
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

    var toStitch: (Layer?, [ValueOrEdge])? {
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

    var toStitch: (Layer?, [ValueOrEdge])? {
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
    var toStitch: (Layer?, [ValueOrEdge])? {
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
    var toStitch: (Layer?, [ValueOrEdge])? {
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

    var toStitch: (Layer?, [ValueOrEdge])? {
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

    var toStitch: (Layer?, [ValueOrEdge])? {
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
    var toStitch: (Layer?, [ValueOrEdge])? {
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
    var toStitch: (Layer?, [ValueOrEdge])? {
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

    var toStitch: (Layer?, [ValueOrEdge])? {
        (.oval, [])                             // no args, nothing to edge
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        node.arguments.isEmpty ? .plain : nil
    }
}

enum EllipseViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                                  // Ellipse()

    var toStitch: (Layer?, [ValueOrEdge])? {
        (.oval, [])                             // same mapping as Circle
    }

    static func from(_ node: FunctionCallExprSyntax) -> Self? {
        node.arguments.isEmpty ? .plain : nil
    }
}

enum RectangleViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case plain                                    // Rectangle()

    var toStitch: (Layer?, [ValueOrEdge])? {
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
    var toStitch: (Layer?, [ValueOrEdge])? {
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
    
    // MARK: Stitch mapping
    ///
    /// • Always returns `(.scroll, …)`
    /// • `.horizontal`   →  scrollXEnabled = true
    /// • `.vertical`     →  scrollYEnabled = true   (default if no arg)
    /// • `[.horizontal, .vertical]` or `.all`
    ///                    →  both scrollXEnabled & scrollYEnabled = true
    /// • Any expression  →  single `.edge(expr)` (caller decides)
    var toStitch: (Layer?, [ValueOrEdge])? {
        guard case let .parameters(axes, _) = self else { return nil }
        var list: [ValueOrEdge] = []
        
        switch axes {
        case .literal(let set):
            // Axis.Set is an OptionSet; test for membership.
            if set.contains(.horizontal) {
                list.append(.value(.init(.scrollXEnabled, .bool(true))))
            }
            if set.contains(.vertical) {
                list.append(.value(.init(.scrollYEnabled, .bool(true))))
            }
            if set == [.horizontal, .vertical] {
                // Already handled by the contains checks, nothing extra
            }
            // If neither bit is set (shouldn’t happen), default to vertical
            if list.isEmpty {
                list.append(.value(.init(.scrollYEnabled, .bool(true))))
            }
            
        case .expression(let expr):
            // Try to evaluate at compile‑time
            if let litSet = expr.axisSetLiteral() {
                if litSet.contains(.horizontal) {
                    list.append(.value(.init(.scrollXEnabled, .bool(true))))
                }
                if litSet.contains(.vertical) || litSet.isEmpty {
                    list.append(.value(.init(.scrollYEnabled, .bool(true))))
                }
            } else {
                // Unresolved at compile‑time → forward as edge
                list.append(.edge(expr))
            }
        }
        
        return (
            nil, // ScrollView does not technically correspond to a Stitch Layer
            list
        )
    }
    
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
    var toStitch: (Layer?, [ValueOrEdge])? {
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
        let colors: Parameter<[Color]>
        if let arr = colorsArg.expression.literalArray({ $0.colorLiteral }),
           arr.count >= 2 {
            colors = .literal(arr)
        } else {
            colors = .expression(colorsArg.expression)
        }

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
    var toStitch: (Layer?, [ValueOrEdge])? {
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
        let colors: Parameter<[Color]>
        if let arr = colorsArg.expression.literalArray({ $0.colorLiteral }),
           arr.count >= 2 {
            colors = .literal(arr)
        } else {
            colors = .expression(colorsArg.expression)
        }

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
    var toStitch: (Layer?, [ValueOrEdge])? {
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

        // ----- colors ---------------------------------------------------
        let colors: Parameter<[Color]>
        if let arr = args[safe: 0]!.expression.literalArray({ $0.colorLiteral }),
           arr.count >= 2 {
            colors = .literal(arr)
        } else {
            colors = .expression(args[safe: 0]!.expression)
        }

        // ----- center (UnitPoint) --------------------------------------
        let centerArg = args[safe: 1]!
        let center: Parameter<UnitPoint> = centerArg.unitPointLiteral
            .map(Parameter.literal) ?? .expression(centerArg.expression)

        // ----- startRadius / endRadius ---------------------------------
        func radiusParam(_ arg: LabeledExprSyntax) -> Parameter<CGFloat> {
            if let num = arg.cgFloatValue { return .literal(num) }
            return .expression(arg.expression)
        }
        let startR = radiusParam(args[safe: 2]!)
        let endR   = radiusParam(args[safe: 3]!)

        return .parameters(colors: colors,
                           center: center,
                           startRadius: startR,
                           endRadius:   endR)
    }
}
