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

    /// Which transformation stages should be displayed.
    enum Stage: CaseIterable, Hashable {
        case originalCode, parsedSyntax, derivedActions, rebuiltSyntax, regeneratedCode

        /// User‑facing title for each stage.
        var title: String {
            switch self {
            case .originalCode:      return "Original SwiftUI code"
            case .parsedSyntax:      return "Parsed SyntaxView"
            case .derivedActions:    return "Derived StitchActions"
            case .rebuiltSyntax:     return "Re‑built SyntaxView"
            case .regeneratedCode:   return "Regenerated SwiftUI code"
            }
        }
    }

    // MARK: Demo snippets (copied from Code→Syntax→Actions view)
    private static let examples = MappingExamples.codeExamples

    // MARK: - UI State
    @State private var selectedTab = 0
    @State private var codes: [String] = examples.map(\.code)

    // Derived / transient state for current tab
    @State private var firstSyntax: SyntaxView?
    @State private var stitchActions: VPLActionOrderedSet = []
    @State private var rebuiltSyntax: SyntaxView?
    @State private var regeneratedCode: String = ""

    /// Controls which columns are visible.  Defaults to showing all.
    @State private var visibleStages: Set<Stage> = Set(Stage.allCases)

    init(initialVisibleStages: Set<Stage> = Set(Stage.allCases)) {
        _visibleStages = State(initialValue: initialVisibleStages)
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 12) {
            Text("Full Round‑Trip Explorer")
                .font(.title2).bold()

            // Toggle bar to show/hide individual transformation stages
            HStack(spacing: 12) {
                ForEach(Stage.allCases, id: \.self) { stage in
                    Button(action: { toggleStage(stage) }) {
                        Label(stage.title,
                              systemImage: visibleStages.contains(stage)
                              ? "checkmark.circle.fill"
                              : "circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)

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
            .onChange(of: selectedTab) { _ in transform() }
        }
        .padding()
        .onAppear { transform() }   // auto‑transform as soon as the view appears
    }

    /// Toggles visibility for a single stage with animation.
    private func toggleStage(_ stage: Stage) {
        withAnimation {
            if visibleStages.contains(stage) {
                visibleStages.remove(stage)
            } else {
                visibleStages.insert(stage)
            }
        }
    }

    // MARK: - Single‑tab layout
    @ViewBuilder
    private func roundTripLayout(for idx: Int) -> some View {
        let binding = Binding<String>(
            get: { codes[idx] },
            set: { codes[idx] = $0; transform() }
        )

        HStack(spacing: 18) {
            ForEach(Stage.allCases.filter { visibleStages.contains($0) }, id: \.self) { stage in
                switch stage {

                case .originalCode:
                    Group {
                        stageView(
                            title: Stage.originalCode.title,
                            text: codes[idx],
                            isEditor: true,
                            editorBinding: binding
                        )
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))

                case .parsedSyntax:
                    Group {
                        stageView(
                            title: Stage.parsedSyntax.title,
                            text: firstSyntax.map { formatSyntaxView($0) } ?? "—"
                        )
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))

                case .derivedActions:
                    Group {
                        stageView(
                            title: Stage.derivedActions.title,
                            text: stitchActions.humanReadable
                        )
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))

                case .rebuiltSyntax:
                    Group {
                        stageView(
                            title: Stage.rebuiltSyntax.title,
                            text: rebuiltSyntax.map { formatSyntaxView($0) } ?? "—"
                        )
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))

                case .regeneratedCode:
                    Group {
                        stageView(
                            title: Stage.regeneratedCode.title,
                            text: regeneratedCode.isEmpty ? "—" : regeneratedCode
                        )
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                }
            }
        }
    }

    // MARK: Helpers
    private func transform() {
        let currentCode = codes[selectedTab]

        // Parse code → Syntax
        guard let syntax = parseSwiftUICode(currentCode) else {
            firstSyntax = nil
            stitchActions = []
            rebuiltSyntax = nil
            regeneratedCode = ""
            return
        }
        firstSyntax = syntax

        // Syntax → Actions
        stitchActions = syntax.deriveStitchActions() ?? []

        // Actions → Syntax
        rebuiltSyntax = SyntaxView.build(from: stitchActions)

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
private extension VPLActionOrderedSet {

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
    private func describe(_ concept: VPLAction, indent: String) -> String {
        switch concept {
        case .createNode(let layer):
            return describe(layer, indent: indent)
        case .setInput(let set):
            return "\(indent)setInput(layerID: \(set.id), input: \(set.input), value: \(set.value))"
        case .createEdge(let edge):
            return "\(indent)incomingEdge(toInput: \(edge.name))"
        }
    }

    /// Formats a layer and its children recursively.
    private func describe(_ layer: VPLCreateNode, indent: String) -> String {
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
