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


typealias NEAInputCase = NonEmptyArray<ValueOrEdge>


enum ValueOrEdge: Equatable, Hashable {
    case value(input: LayerInputPort, value: PortValue)
    case edge(input: LayerInputPort, from: Int)
}

struct CustomValue: Equatable, Hashable {
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
    var toStitch: (Layer, [CustomValue])? { get }
    
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
    case string(_ content: String)

    /// `Text(_ key: LocalizedStringKey)`
    case localized(_ key: LocalizedStringKey)

    /// `Text(verbatim: "Raw")`
    case verbatim(_ content: String)

    /// `Text(_ attributed: AttributedString)`
    case attributed(_ content: AttributedString)

    
    var toStitch: (Layer, [CustomValue])? {
         switch self {
             
         case .string(let s),
              .verbatim(let s):      // treat verbatim the same
             return (
                .text,
                [
                    .init(.text, .string(.init(s)))
                ]
             )

         case .localized(let key):
             return (
                .text,
                [
                    .init(.text, .string(.init(key.resolved)))
                ]
             )

         case .attributed(let attr):
             return (
                .text,
                [
                    .init(.text, .string(.init(attr.plainText)))
                ]
             )
         }
     }
    
    // Factory that infers the correct overload from a `FunctionCallExprSyntax`
    static func from(_ node: FunctionCallExprSyntax) -> TextViewConstructor? {
        let args = node.arguments

        // 1. Text("Hello")
        if args.count == 1, args.first!.label == nil,
           let lit = args.first!.expression.as(StringLiteralExprSyntax.self) {
            return .string(lit.decoded())
        }

        // 2. Text(verbatim: "Raw")
        if let first = args.first,
           first.label?.text == "verbatim",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            return .verbatim(lit.decoded())
        }

        // 3. Text(LocalizedStringKey("key"))
        if args.count == 1,
           args.first!.label == nil,
           let call = args.first!.expression.as(FunctionCallExprSyntax.self),
           let id = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
           id == "LocalizedStringKey",
           let lit = call.arguments.first?.expression.as(StringLiteralExprSyntax.self) {
            return .localized(LocalizedStringKey(lit.decoded()))
        }

        // 4. Text(AttributedString("Fancy"))
        if args.count == 1,
           args.first!.label == nil,
           let call = args.first!.expression.as(FunctionCallExprSyntax.self),
           let id = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
           id == "AttributedString",
           let lit = call.arguments.first?.expression.as(StringLiteralExprSyntax.self) {
            return .attributed(AttributedString(lit.decoded()))
        }

        return nil
    }
}


enum ImageViewConstructor: Equatable, FromSwiftUIViewToStitch {
    /// `Image("assetName", bundle: nil)`
    case asset(_ name: String, bundle: Bundle? = nil)

    /// `Image(systemName: "gear")`
    case sfSymbol(_ name: String)

    /// `Image(decorative:name:bundle:)`
    case decorative(_ name: String, bundle: Bundle? = nil)

    // TODO: support this case
//    /// `Image(initResource:)`
//    case resource(_ resource: ImageResource)

    /// `Image(uiImage:)`
    case uiImage(_ image: UIImage)
  
    var toStitch: (Layer, [CustomValue])? {
        switch self {

        //  Image("logo")  |  Image("photo", bundle: …)
        case .asset(let name, _),
             .decorative(let name, _):
            return (
                .image,
                [
                    .init(.image, .string(.init(name)))
                ]
            )

        //  Image(systemName: "gear")
        case .sfSymbol(let name):
            return (
                .image,
                [
                    .init(.sfSymbol, .string(.init(name)))
                ]
            )

        //  Image(uiImage: …)  – placeholder async media
        case .uiImage(_):
            return (
                .image,
                [
                    .init(.image, .asyncMedia(nil))
                ]
            )
        }
    }
    
    // Factory that infers the correct overload from a `FunctionCallExprSyntax`
    static func from(_ node: FunctionCallExprSyntax) -> ImageViewConstructor? {
        let args = node.arguments
        guard let first = args.first else { return nil }

        // 1. Image(systemName:)
        if first.label?.text == "systemName",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            return .sfSymbol(lit.decoded())
        }

        // 2. Image("asset"[, bundle:])
        if first.label == nil,
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            var bundle: Bundle? = nil
            if args.count > 1,
               let bArg = args.dropFirst().first,
               bArg.label?.text == "bundle" {
                bundle = .main            // simplified
            }
            return .asset(lit.decoded(), bundle: bundle)
        }

        // 3. Image(decorative: "name"[, bundle:])
        if first.label?.text == "decorative",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            var bundle: Bundle? = nil
            if args.count > 1,
               let bArg = args.dropFirst().first,
               bArg.label?.text == "bundle" {
                bundle = .main
            }
            return .decorative(lit.decoded(), bundle: bundle)
        }

        // 4. Image(uiImage:)
        if first.label?.text == "uiImage" {
            return .uiImage(UIImage())   // placeholder
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
    case parameters(alignment: VerticalAlignment = .center,
                    spacing: CGFloat? = nil)

    // MARK: Stitch mapping
    var toStitch: (Layer, [CustomValue])? {
        // orientation is always horizontal
        var values: [CustomValue] = [
            .init(.orientation, .orientation(.horizontal))
        ]

        switch self {
        case .parameters(let alignment, let spacing):

            // Only emit alignment if it differs from default .center
            if alignment != .center {
                values.append(.init(.layerGroupAlignment,
                                    .anchoring(alignment.toAnchoring)))
            }

            // Only emit spacing if the developer provided one
            if let s = spacing {
                values.append(.init(.spacing, .spacing(.number(s))))
            }
        }

        return (.group, values)
    }

    // MARK: Parse from SwiftSyntax
    static func from(_ node: FunctionCallExprSyntax) -> HStackViewConstructor? {
        let args = node.arguments

        // defaults
        var alignment: VerticalAlignment = .center
        var spacing: CGFloat? = nil

        // iterate through labelled args
        for arg in args {
            switch arg.label?.text {
            case "alignment":
                alignment = arg.vertAlignValue
            case "spacing":
                spacing = arg.cgFloatValue
            default:
                // ignore other labels (content closure etc.)
                break
            }
        }

        return .parameters(alignment: alignment, spacing: spacing)
    }
}

enum VStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case alignmentSpacing(alignment: HorizontalAlignment, spacing: CGFloat?)
    case alignment(alignment: HorizontalAlignment)
    case spacing(CGFloat?)
    case none

    var toStitch: (Layer, [CustomValue])? {
        var values: [CustomValue] = [
            .init(.orientation, .orientation(.vertical))
        ]

        switch self {
        case .alignmentSpacing(let alignment, let spacing):
            values.append(.init(.layerGroupAlignment, .anchoring(alignment.toAnchoring)))
            if let s = spacing {
                values.append(.init(.spacing, .spacing(.number(s))))
            }

        case .alignment(let alignment):
            values.append(.init(.layerGroupAlignment, .anchoring(alignment.toAnchoring)))

        case .spacing(let spacing):
            if let s = spacing {
                values.append(.init(.spacing, .spacing(.number(s))))
            }

        case .none:
            break
        }

        return (.group, values)
    }

    static func from(_ node: FunctionCallExprSyntax) -> VStackViewConstructor? {
        let args = node.arguments
        switch (args.count,
                args.first?.label?.text,
                args.dropFirst().first?.label?.text) {

        // alignment + spacing
        case (2, "alignment", "spacing"):
            let a = args[safe: 0]?.horizAlignValue ?? .center
            let s = args[safe: 1]?.cgFloatValue
            return .alignmentSpacing(alignment: a, spacing: s)

        // alignment only
        case (1, "alignment", _):
            let a = args[safe: 0]?.horizAlignValue ?? .center
            return .alignment(alignment: a)

        // spacing only
        case (1, "spacing", _):
            let s = args[safe: 0]?.cgFloatValue
            return .spacing(s)

        // no args
        case (0, _, _):
            return nil

        default:
            return nil
        }
    }
}

// ── Helper: random-access a TupleExprElementListSyntax by Int index ────────────
private extension LabeledExprListSyntax {
    subscript(safe index: Int) -> LabeledExprSyntax? {
        guard index >= 0 && index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }
}

enum LazyHStackViewConstructor: Equatable, FromSwiftUIViewToStitch {
    case parameters(alignment: VerticalAlignment = .center,
                    spacing: CGFloat? = nil)

    var toStitch: (Layer, [CustomValue])? {
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
    case alignmentSpacing(alignment: HorizontalAlignment, spacing: CGFloat?)
    case alignment(alignment: HorizontalAlignment)
    case spacing(CGFloat?)
    case none

    var toStitch: (Layer, [CustomValue])? {
        switch self {
        case .alignmentSpacing(let a, let s):
            return VStackViewConstructor.alignmentSpacing(alignment: a, spacing: s).toStitch
        case .alignment(let a):
            return VStackViewConstructor.alignment(alignment: a).toStitch
        case .spacing(let s):
            return VStackViewConstructor.spacing(s).toStitch
        case .none:
            return VStackViewConstructor.none.toStitch
        }
    }

    static func from(_ node: FunctionCallExprSyntax) -> LazyVStackViewConstructor? {
        VStackViewConstructor.from(node).flatMap {
            switch $0 {
            case .alignmentSpacing(let a, let s): return .alignmentSpacing(alignment: a, spacing: s)
            case .alignment(let a):               return .alignment(alignment: a)
            case .spacing(let s):                 return .spacing(s)
            case .none:                           return nil
            }
        }
    }
}


// ── Tiny extraction helpers for alignment / spacing literals ─────────────
private extension LabeledExprSyntax {
    var cgFloatValue: CGFloat? {
        if let float = expression.as(FloatLiteralExprSyntax.self) {
            return CGFloat(Double(float.literal.text) ?? 0)
        }
        if let int = expression.as(IntegerLiteralExprSyntax.self) {
            return CGFloat(Double(int.literal.text) ?? 0)
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
    VStack {
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

        LazyHStack // { Text("C") }
        LazyHStack(alignment: .top) // { Text("C") }
        LazyHStack(spacing: 8) // { Text("C") }

        LazyVStack // { Text("D") }
        LazyVStack(alignment: .leading) // { Text("D") }
        LazyVStack(spacing: 4) // { Text("D") }
    }
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
                    .map { "\($0.input)=\($0.value.display)" }
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

                    Text(row.overload)
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(row.stitch)
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .border(.red, width: 4)
    }
}
