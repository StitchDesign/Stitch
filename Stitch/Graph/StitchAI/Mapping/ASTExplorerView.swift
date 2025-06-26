
//
//  ASTExplorerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/25.
//  Re‑written to demonstrate the entire round‑trip flow:
//  Code → Syntax → Actions → Syntax → Code
//

import SwiftUI
import SwiftSyntax
import SwiftParser


/// Playground that shows the *full* Stitch round‑trip.
/// You type SwiftUI code → it is parsed into `SyntaxView` → converted
/// to `StitchActions` → rebuilt back into a `SyntaxView` → and then
/// rendered as regenerated SwiftUI source.  All five stages are displayed
/// side‑by‑side so you can visually verify loss‑/faithfulness.
struct ASTExplorerView: View {

    // MARK: Demo snippets (copied from Code→Syntax→Actions view)
    private static let examples = Self.codeExamples

    // MARK: - UI State
    @State private var selectedTab = 0
    @State private var codes: [String] = examples.map(\.code)

    // Derived / transient state for current tab
    @State private var firstSyntax: SyntaxView?
    @State private var stitchedActions: VPLLayerConceptOrderedSet = []
    @State private var rebuiltSyntax: SyntaxView?
    @State private var regeneratedCode: String = ""

    // MARK: Body
    var body: some View {
        VStack(spacing: 12) {
            Text("Full Round‑Trip Explorer")
                .font(.title2).bold()

            Button("Transform") { transform() }
                .buttonStyle(.borderedProminent)

            TabView(selection: $selectedTab) {
                ForEach(Self.examples.indices, id: \.self) { idx in
                    roundTripLayout(for: idx)
                        .tabItem { Text(Self.examples[idx].title) }
                        .tag(idx)
                }
            }
            .tabViewStyle(.automatic)
            .onAppear { transform() }
            .onChange(of: selectedTab) { _ in transform() }
        }
        .padding()
    }

    // MARK: - Single‑tab layout
    @ViewBuilder
    private func roundTripLayout(for idx: Int) -> some View {
        let binding = Binding<String>(
            get: { codes[idx] },
            set: { codes[idx] = $0; transform() }
        )

        HStack(spacing: 18) {
            stageView(
                title: "Original SwiftUI code",
                text: codes[idx],
                isEditor: true,
                editorBinding: binding
            )
            stageView(
                title: "Parsed SyntaxView",
                text: firstSyntax.map { formatSyntaxView($0) } ?? "—"
            )
            stageView(
                title: "Derived StitchActions",
                text: stitchedActions.humanReadable
            )
            stageView(
                title: "Re‑built SyntaxView",
                text: rebuiltSyntax.map { formatSyntaxView($0) } ?? "—"
            )
            stageView(
                title: "Regenerated SwiftUI code",
                text: regeneratedCode.isEmpty ? "—" : regeneratedCode
            )
        }
        .padding(.vertical)
    }

    // MARK: Helpers
    private func transform() {
        let currentCode = codes[selectedTab]

        // Parse code → Syntax
        guard let syntax = parseSwiftUICode(currentCode) else {
            firstSyntax = nil
            stitchedActions = []
            rebuiltSyntax = nil
            regeneratedCode = ""
            return
        }
        firstSyntax = syntax

        // Syntax → Actions
        stitchedActions = syntax.deriveStitchActions()

        // Actions → Syntax
        rebuiltSyntax = SyntaxView.build(from: stitchedActions)

        // Syntax → Code
        if let rebuilt = rebuiltSyntax {
            regeneratedCode = swiftUICode(from: rebuilt)
        } else {
            regeneratedCode = ""
        }
    }

    /// Utility helper to build either read‑only or editable stage views.
    @ViewBuilder
    private func stageView(title: String,
                           text: String,
                           isEditor: Bool = false,
                           editorBinding: Binding<String>? = nil) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if isEditor, let binding = editorBinding {
                TextEditor(text: binding)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary)
                    .onChange(of: binding.wrappedValue) { _ in transform() }
            } else {
                ScrollView {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .border(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: – Pretty‑printing helpers for VPL actions
private extension VPLLayerConceptOrderedSet {

    /// A multi‑line, human‑readable description of the ordered actions list.
    /// Returns “—” when the set is empty.
    var humanReadable: String {
        guard !isEmpty else { return "—" }
        return enumerated()
            .map { "\n[\($0)] \(describe($1, indent: ""))" }
            .joined(separator: "\n")
    }

    // MARK: - Internals

    /// Formats a single concept.
    private func describe(_ concept: VPLLayerConcept, indent: String) -> String {
        switch concept {
        case .layer(let layer):
            return describe(layer, indent: indent)
        case .layerInputSet(let set):
            return "\(indent)setInput(layerID: \(set.id), input: \(set.input), value: \(set.value))"
        case .incomingEdge(let edge):
            return "\(indent)incomingEdge(toInput: \(edge.name))"
        }
    }

    /// Formats a layer and its children recursively.
    private func describe(_ layer: VPLLayer, indent: String) -> String {
        var lines: [String] = []
        lines.append("\(indent)layer(id: \(layer.id), name: \(layer.name.defaultDisplayTitle())) {")
        if layer.children.isEmpty {
            lines.append("\(indent)    (no children)")
        } else {
            for child in layer.children {
                lines.append(describe(child, indent: indent + "    "))
            }
        }
        lines.append("\(indent)}")
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
struct ASTExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        ASTExplorerView()
            .frame(minWidth: 1600, minHeight: 800)
    }
}
#endif
