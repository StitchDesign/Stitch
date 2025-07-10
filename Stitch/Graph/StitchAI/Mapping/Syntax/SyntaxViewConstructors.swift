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


protocol FromSwiftUIViewToStitch {
    
    // Really, should be: (Layer, NonEmptyArray<ManualValueOrIncomingEdge>)
    // i.e. "this view and constructor overload created this layer and these layer input values/connections"
    var toStitch: (Layer, (LayerInputPort, PortValue))? { get }
}


enum ViewConstructor {
    case text(TextViewConstructor)
    case image(ImageViewConstructor)
}
    

extension AttributedString {
    /// Returns only the textual content (attributes are discarded).
    var plainText: String { self.description }   // `.description` flattens to String
}

extension LocalizedStringKey {
    /// Best‑effort: resolves through the app’s main bundle; falls back to the key itself.
    var resolved: String {
        let keyString = String(describing: self)   // mirrors what the dev wrote
        return NSLocalizedString(keyString,
                                 bundle: .main,
                                 value: keyString,
                                 comment: "")
    }
}

enum TextViewConstructor: FromSwiftUIViewToStitch {
    /// `Text("Hello")`
    case string(_ content: String)

    /// `Text(_ key: LocalizedStringKey)`
    case localized(_ key: LocalizedStringKey)

    /// `Text(verbatim: "Raw")`
    case verbatim(_ content: String)

    /// `Text(_ attributed: AttributedString)`
    case attributed(_ content: AttributedString)

    
    var toStitch: (Layer, (LayerInputPort, PortValue))? {
         switch self {
             
         case .string(let s),
              .verbatim(let s):      // treat verbatim the same
             return (.text,
                     (.text, .string(.init(s))))

         case .localized(let key):
             return (.text,
                     (.text, .string(.init(key.resolved))))

         case .attributed(let attr):
             return (.text,
                     (.text, .string(.init(attr.plainText))))
         }
     }
    
}


enum ImageViewConstructor: FromSwiftUIViewToStitch {
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
  
    var toStitch: (Layer, (LayerInputPort, PortValue))? {
        switch self {

        // MARK: ‑ plain asset names  ───────────────────────────────────
        //  Image("logo")  |  Image("photo", bundle: …)
        case .asset(let name, _),
             .decorative(let name, _):    // treat decorative same for now
            return (
                .image,
                (
                    .image,
                    .string(.init(name))
                )
            )

        // MARK: ‑ SF Symbols  ──────────────────────────────────────────
        //  Image(systemName: "gear")
        case .sfSymbol(let name):
            return (
                .image,
                (
                    .sfSymbol,
                    .string(.init(name))
                )
            )

        // MARK: ‑ platform image payloads  ─────────────────────────────
        //  Image(uiImage: UIImage)
        case .uiImage(_ /* img */):
            // Stitch currently stores raw image payloads on the .image port;
            // we pass `.none` as a placeholder – real media is handled elsewhere.
            return (
                .image,
                (
                    .image,
                    .asyncMedia(nil)
                )
            )
        }
    }
}


// MARK: - Proof‑of‑Concept Visitor ----------------------------------------
//
//  This visitor is *stand‑alone* and confined to this file so you can
//  experiment without touching the real parsing pipeline elsewhere.
//
import SwiftSyntax
import SwiftParser

/// A lightweight record of each Text / Image call we find.
struct POCViewCall {
    enum Kind {
        case text(TextViewConstructor)
        case image(ImageViewConstructor)
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

        guard let calleeIdent = node.calledExpression.as(IdentifierExprSyntax.self)?
                                  .identifier.text
        else { return .skipChildren }
        
        print("POCVisitor: visiting \(calleeIdent) – args: \(node.argumentList.count)")

        switch calleeIdent {

        // -------- TEXT -------------------------------------------------
        case "Text":
            if let ctor = classifyText(node) {
                calls.append(.init(kind: .text(ctor), node: node))
                print("POCVisitor: recorded call – total so far = \(calls.count)")
            }

        // -------- IMAGE ------------------------------------------------
        case "Image":
            if let ctor = classifyImage(node) {
                calls.append(.init(kind: .image(ctor), node: node))
                print("POCVisitor: recorded call – total so far = \(calls.count)")
            }

        default:
            break
        }
        return .visitChildren
    }

    // MARK: POC helpers -------------------------------------------------

    private func classifyText(_ node: FunctionCallExprSyntax) -> TextViewConstructor? {
        let args = node.argumentList
        print("classifyText: inspecting args →", args.map { ($0.label?.text ?? "_") })
        // 1. Text("Hello")
        if args.count == 1, args.first!.label == nil,
           let lit = args.first!.expression.as(StringLiteralExprSyntax.self) {
            print("classifyText: matched .string \"\(lit.decoded())\"")
            return .string(lit.decoded())
        }
        // 2. Text(verbatim: "Raw")
        if let first = args.first,
           first.label?.text == "verbatim",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            print("classifyText: matched .verbatim \"\(lit.decoded())\"")
            return .verbatim(lit.decoded())
        }
        // 3. Text(LocalizedStringKey("key")) or Text(AttributedString("..."))
        if args.count == 1,
           args.first!.label == nil,
           let call = args.first!.expression.as(FunctionCallExprSyntax.self),
           let id   = call.calledExpression.as(IdentifierExprSyntax.self)?.identifier.text {

            if id == "LocalizedStringKey",
               let lit = call.argumentList.first?.expression.as(StringLiteralExprSyntax.self) {
                print("classifyText: matched .localized \"\(lit.decoded())\"")
                return .localized(LocalizedStringKey(lit.decoded()))
            }

            if id == "AttributedString",
               let lit = call.argumentList.first?.expression.as(StringLiteralExprSyntax.self) {
                print("classifyText: matched .attributed \"\(lit.decoded())\"")
                return .attributed(AttributedString(lit.decoded()))
            }
        }
        // 4. Fallback – not recognised
        print("classifyText: no match")
        return nil
    }

    private func classifyImage(_ node: FunctionCallExprSyntax) -> ImageViewConstructor? {
        let args = node.argumentList
        print("classifyImage: inspecting args →", args.map { ($0.label?.text ?? "_") })
        // Image(systemName: "gear")
        if let first = args.first,
           first.label?.text == "systemName",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            print("classifyImage: matched .sfSymbol \"\(lit.decoded())\"")
            return .sfSymbol(lit.decoded())
        }
        // Image(decorative: "name", bundle: ...)
        if let first = args.first,
           first.label?.text == "decorative",
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            print("classifyImage: matched .decorative \"\(lit.decoded())\"")
            return .decorative(lit.decoded(), bundle: nil)   // bundle detection skipped for brevity
        }
//        // Image(initResource: .init(name: "photo"))
//        if let first = args.first,
//           first.label?.text == "initResource" {
//            print("classifyImage: matched .resource <placeholder>")
//            return .resource(ImageResource())    // placeholder
//        }
        
        // Image(uiImage: someUIImage)
        if let first = args.first,
           first.label?.text == "uiImage" {
            print("classifyImage: matched .uiImage <placeholder>")
            return .uiImage(UIImage())           // placeholder
        }
        // Image("asset")
        if let first = args.first,
           first.label == nil,
           let lit = first.expression.as(StringLiteralExprSyntax.self) {
            print("classifyImage: matched .asset \"\(lit.decoded())\"")
            return .asset(lit.decoded(), bundle: nil)
        }
        print("classifyImage: no match")
        return nil
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

            switch call.kind {
            case .text(let ctor):
                overload = "Text.\(ctor)"
                if let (layer, (port, value)) = ctor.toStitch {
                    stitch = "Layer: \(layer), Input: \(port), Value: \(value.display)"
                } else { stitch = "—" }

            case .image(let ctor):
                overload = "Image.\(ctor)"
                if let (layer, (port, value)) = ctor.toStitch {
                    stitch = "Layer: \(layer), Input: \(port), Value: \(value.display)"
                } else { stitch = "—" }
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
