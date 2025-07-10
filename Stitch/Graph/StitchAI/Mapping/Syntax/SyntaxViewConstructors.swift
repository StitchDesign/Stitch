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
    var toStitch: (Layer, LayerInputPortSet)? { get }
}


enum ViewConstructor {
    case text(TextViewConstructor)
    case image(ImageViewConstructor)
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

    var toStitch: (Layer, LayerInputPortSet)? {
        nil
    }
}


enum ImageViewConstructor: FromSwiftUIViewToStitch {
    /// `Image("assetName", bundle: nil)`
    case asset(_ name: String, bundle: Bundle? = nil)

    /// `Image(systemName: "gear")`
    case sfSymbol(_ name: String)

    /// `Image(decorative:name:bundle:)`
    case decorative(_ name: String, bundle: Bundle? = nil)

    /// `Image(initResource:)`
    case resource(_ resource: ImageResource)

    /// `Image(uiImage:)`
    case uiImage(_ image: UIImage)
  
    var toStitch: (Layer, LayerInputPortSet)? {
        nil
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
        // 3. Fallback – not recognised
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
        Text(verbatim: "Raw")
        Image(systemName: "gear")
        Image("logo")
    }
    """

    let parsedLines: [String] = {
        let tree = Parser.parse(source: Self.sampleSource)
        let visitor = POCConstructorVisitor(viewMode: .fixedUp)
        visitor.walk(tree)
        let lines = visitor.calls.map { call in
            switch call.kind {
            case .text(let ctor):  return "Text  →  \(ctor)"
            case .image(let ctor): return "Image →  \(ctor)"
            }
        }
        print("ConstructorDemoView: parsedLines =", lines)
        return lines
    }()

    var body: some View {
        Text("parsed lines below...")
        List(parsedLines, id: \.self) { line in
            Text(line)
                .monospaced()
        }
        .border(.red, width: 4)
    }
}
