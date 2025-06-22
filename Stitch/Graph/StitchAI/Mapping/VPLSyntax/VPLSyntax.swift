//
//  VPLSyntax.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/22/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser


// MARK: logic

struct ParsedSwiftUIViewDemo: View {
    @State private var viewNode: ViewNode?

    @State private var selectedTab = 0
    
    /// Titles for each demo tab
    private let demoTitles: [String] = [
        "Complex Modifier",
        "ZStack Rectangles",
        "Text",
        "Text with Modifiers",
        "Nested ZStack",
        "Image"
    ]
    
    /// Editable SwiftUI source for each demo
    @State private var demoCodes: [String] = [
        """
        Rectangle()
            .frame(width: 200, height: 100, alignment: .center)
        """,
        """
        ZStack {
            Rectangle().fill(Color.blue)
            Rectangle().fill(Color.green)
        }
        """,
        #"Text("salut")"#,
        #"Text("salut").foregroundColor(Color.yellow).padding()"#,
        """
        ZStack {
            Rectangle().fill(Color.blue)
            VStack {
                Rectangle().fill(Color.green)
                Rectangle().fill(Color.red)
            }
        }
        """,
        #"Image(systemName: "star.fill")"#
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(demoTitles.indices, id: \.self) { idx in
                VStack(alignment: .leading) {
                    
                    // ── Editable SwiftUI Source ─────────────────────────────
                    Text("SwiftUI Source")
                        .font(.headline)
                    TextEditor(text: $demoCodes[idx])
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 140)
                        .border(.secondary)
                        .onChange(of: demoCodes[idx]) { _ in parseCurrent() }
                        
                    Divider()
                    
                    // ── Parsed ViewNode ────────────────────────────────────
                    if let viewNode {
                        ScrollView {
                            Text("Parsed ViewNode")
                                .font(.headline)
                                .padding(.bottom, 2)
                            Text(formatViewNode(viewNode))
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ProgressView("Parsing…")
                    }
                }
                .padding()
                .tabItem { Text(demoTitles[idx]) }
                .tag(idx)
            }
        }
        .onAppear { parseCurrent() }
        .onChange(of: selectedTab) { _ in parseCurrent() }
    }


    private func parseCurrent() {
        let code = demoCodes[selectedTab]
        do {
            viewNode = try parseSwiftUIView(code: code)
        } catch {
            print("Parsing error:", error)
            viewNode = nil
        }
    }
}


// MARK: logic

func parseSwiftUIView(code: String) throws -> ViewNode {
    let syntaxTree = Parser.parse(source: code)
    guard let rootExpr = syntaxTree.statements.first?.item.as(ExprSyntax.self) else {
        throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid SwiftUI code"])
    }
    
    return parseView(expr: rootExpr, id: UUID().uuidString)
}

private func parseView(expr: ExprSyntax, id: String) -> ViewNode {
    switch expr.as(ExprSyntaxEnum.self) {

    case .sequenceExpr(let sequenceExpr):
        guard let firstExpr = sequenceExpr.elements.first else {
            return ViewNode(name: "Unknown", arguments: [], modifiers: [], children: [], id: id)
        }

        var viewNode = parseView(expr: firstExpr, id: UUID().uuidString)

        for childExpr in sequenceExpr.elements.dropFirst() {
            if let memberCall = childExpr.as(FunctionCallExprSyntax.self),
               let memberAccess = memberCall.calledExpression.as(MemberAccessExprSyntax.self) {

                let modifier = Modifier(
                    name: memberAccess.declName.baseName.text,
                    value: "",
                    arguments: memberCall.arguments.compactMap { arg in
                        (label: arg.label?.text, value: arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                )

                viewNode.modifiers.append(modifier)
            } else if let memberAccess = childExpr.as(MemberAccessExprSyntax.self) {
                let modifier = Modifier(
                    name: memberAccess.declName.baseName.text,
                    value: "",
                    arguments: []
                )
                viewNode.modifiers.append(modifier)
            }
        }

        return viewNode

    case .functionCallExpr(let functionCall):
        let viewName = functionCall.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = functionCall.arguments.compactMap { arg in
            (label: arg.label?.text, value: arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return ViewNode(
            name: viewName,
            arguments: arguments,
            modifiers: [],
            children: [],
            id: id
        )

    default:
        return ViewNode(name: "Unknown", arguments: [], modifiers: [], children: [], id: id)
    }
}
