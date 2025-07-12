//
//  DeclarativeViewConstructorsDemoView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser


// MARK: - Proof‑of‑Concept Visitor ----------------------------------------
//
//  This visitor is *stand-alone* and confined to this file so you can
//  experiment without touching the real parsing pipeline elsewhere.
//

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
        ScrollView(.vertical)
        ScrollView([.vertical, .horizontal])
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

    // MARK: - Rows
    @State private var rows: [DemoRow] = ConstructorDemoView.buildRows()
    
    private static func buildRows() -> [DemoRow] {
        let tree = Parser.parse(source: Self.sampleSource)
        let visitor = POCConstructorVisitor(viewMode: .fixedUp)
        visitor.walk(tree)

        return visitor.calls.map { call in
            let code = call.node.description.trimmingCharacters(in: .whitespacesAndNewlines)

            let overload: String
            let stitch: String

            let (prefix, ctor): (String, any FromSwiftUIViewToStitch)

            switch call.kind {
            case .text(let c):             (prefix, ctor) = ("Text", c)
            case .image(let c):            (prefix, ctor) = ("Image", c)
            case .hStack(let c):           (prefix, ctor) = ("HStack", c)
            case .vStack(let c):           (prefix, ctor) = ("VStack", c)
            case .lazyHStack(let c):       (prefix, ctor) = ("LazyHStack", c)
            case .lazyVStack(let c):       (prefix, ctor) = ("LazyVStack", c)
            case .circle(let c):           (prefix, ctor) = ("Circle", c)
            case .ellipse(let c):          (prefix, ctor) = ("Ellipse", c)
            case .rectangle(let c):        (prefix, ctor) = ("Rectangle", c)
            case .roundedRectangle(let c): (prefix, ctor) = ("RoundedRectangle", c)
            case .scrollView(let c):       (prefix, ctor) = ("ScrollView", c)
            case .zStack(let c):           (prefix, ctor) = ("ZStack", c)
            case .textField(let c):        (prefix, ctor) = ("TextField", c)
            case .angularGradient(let c):  (prefix, ctor) = ("AngularGradient", c)
            case .linearGradient(let c):   (prefix, ctor) = ("LinearGradient", c)
            case .radialGradient(let c):   (prefix, ctor) = ("RadialGradient", c)
            }

            overload = "\(prefix).\(ctor)"
            if let (layer, values) = ctor.toStitch {
                let detail = values.map { ve -> String in
                    switch ve {
                    case .value(let cv):
                        return "\(cv.input)=\(cv.value.display)"
                    case .edge(let expr):
                        return "edge<\(expr.description)>"
                    }
                }.joined(separator: ", ")
                stitch = "Layer: \(String(describing: layer))  { \(detail) }"
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

            Button("Run conversions again") {
                rows = ConstructorDemoView.buildRows()
            }
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
