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
    
    // Really, should be: (Layer, NonEmptyArray<ManualValueOrIncomingEdge>)
    // i.e. "this view and constructor overload created this layer and these layer input values/connections"
    var toStitch: (Layer, [ValueOrEdge])? { get }
    
    static func from(_ node: FunctionCallExprSyntax) -> T?
}


enum ViewConstructor: Equatable {
    case text(TextViewConstructor)
    case image(ImageViewConstructor)
    case hStack(HStackViewConstructor)
    case vStack(VStackViewConstructor)
    case lazyHStack(LazyHStackViewConstructor)
    case lazyVStack(LazyVStackViewConstructor)
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

// what about
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


// ── Tiny extraction helpers for alignment / spacing literals ─────────────
extension LabeledExprSyntax {
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

    var horizAlignValue: HorizontalAlignment {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text
        {
            switch ident {
            case "leading":  return .leading
            case "trailing": return .trailing
            default:         return .center
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
}

private extension Parameter where Value: CustomStringConvertible {
    /// Fragment suitable for regenerating Swift source.
    var swiftFragment: String {
        switch self {
        case .literal(let v):    return String(describing: v)
        case .expression(let e): return e.description
        }
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
                print("POCVisitor: recorded call – total so far = \(calls.count)")
            }

        case "Image":
            if let ctor = ImageViewConstructor.from(node) {
                calls.append(.init(kind: .image(ctor), node: node))
                print("POCVisitor: recorded call – total so far = \(calls.count)")
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
            
        default:
            break
        }
        return .visitChildren
    }
}

// MARK: - Tiny helpers -----------------------------------------------------

private extension StringLiteralExprSyntax {
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
    """

    // One row of the demo table
    struct DemoRow: Identifiable {
        let id = UUID()
        let code: String
        let overload: String
        let stitch: String
    }

    private var rows: [DemoRow] {
        let tree = Parser.parse(source: Self.sampleSource)
        let visitor = POCConstructorVisitor(viewMode: .fixedUp)
        visitor.walk(tree)

        return visitor.calls.map { call in
            let code = call.node.description.trimmingCharacters(in: .whitespacesAndNewlines)

            let overload: String
            let stitch: String

            let (prefix, ctor): (String, any FromSwiftUIViewToStitch)

            switch call.kind {
            case .text(let c):        (prefix, ctor) = ("Text", c)
            case .image(let c):       (prefix, ctor) = ("Image", c)
            case .hStack(let c):      (prefix, ctor) = ("HStack", c)
            case .vStack(let c):      (prefix, ctor) = ("VStack", c)
            case .lazyHStack(let c):  (prefix, ctor) = ("LazyHStack", c)
            case .lazyVStack(let c):  (prefix, ctor) = ("LazyVStack", c)
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
