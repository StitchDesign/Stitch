//
//  SyntaxToActionsExploratoryView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import SwiftUI

// MARK: - Demo / Playground UI

/// A playground-style view that lets you
/// 1. edit a SwiftUI snippet,
/// 2. see the parsed `ViewNode`,
/// 3. see the derived StitchActions – all side-by-side.
struct CodeToSyntaxToActionsExploratoryView: View {

    // -- Demo snippets to cycle through --
    private let examples = MappingExamples.codeExamples
    // -- UI State --
    @State private var selectedTab = 0
    @State private var swiftUICode: String = ""
    @State private var parsedViewNode: SyntaxView?
    @State private var actions: VPLLayerConceptOrderedSet = []

    // -- Body --
    var body: some View {
        VStack(spacing: 12) {
            Text("Code → Syntax → Actions")
                .font(.title2).bold()

            Button("Parse") { parseCurrent() }
                .buttonStyle(.borderedProminent)

            TabView(selection: $selectedTab) {
                ForEach(examples.indices, id: \.self) { idx in
                    tabContent(for: idx)
                        .tabItem { Text(examples[idx].title) }
                        .tag(idx)
                }
            }
            .tabViewStyle(.automatic)
            .onAppear { loadExample(0) }
            .onChange(of: selectedTab) { loadExample($0) }
        }
        .padding()
    }

    // -- Single-tab layout --
    @ViewBuilder
    private func tabContent(for idx: Int) -> some View {
        HStack(spacing: 18) {

            // Editable SwiftUI code
            VStack(alignment: .leading) {
                Text("Code").font(.headline)
                TextEditor(text: $swiftUICode)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: swiftUICode) { _ in parseCurrent() }
                    .padding()
                    .border(Color.secondary)
            }
            

            // Parsed ViewNode
            VStack(alignment: .leading) {
                Text("Syntax").font(.headline)
                ScrollView {
                    if let node = parsedViewNode {
                        Text(formatSyntaxView(node))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        Text("—")
                    }
                }
                .border(Color.secondary)
            }

            // Derived StitchActions
            VStack(alignment: .leading) {
                Text("Actions").font(.headline)
                ScrollView {
                    if actions.isEmpty {
                        Text("—")
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(actions.enumerated()), id: \.element) { idx, act in
                                Text("[\(idx)] \(String(describing: act))")
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .border(Color.secondary)
            }
        }
        .padding(.vertical)
    }

    // -- Helpers --
    private func loadExample(_ idx: Int) {
        swiftUICode = examples[idx].code
        parseCurrent()
    }

    private func parseCurrent() {
        parsedViewNode = parseSwiftUICode(swiftUICode)
        if let node = parsedViewNode {
            actions = node.deriveStitchActions()
        } else {
            actions = []
        }
    }
}
