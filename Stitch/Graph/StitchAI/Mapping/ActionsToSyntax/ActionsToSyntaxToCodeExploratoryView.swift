//
//  ActionsToSyntaxToCodeExploratoryView.swift
//  Stitch
//
//  Created by ChatGPT on 6/24/25.
//

import SwiftUI


extension ActionsToSyntaxToCodeExploratoryView {
        
    
}

/// Playground view that lets you:
/// 1. Paste or edit a JSON array of StitchActions (`VPLLayerConceptOrderedSet`),
/// 2. Convert them into a `SyntaxView`,
/// 3. Generate the equivalent SwiftUI source code – all side‑by‑side.
struct ActionsToSyntaxToCodeExploratoryView: View {

    // Demo sets to cycle through
    private static let examples = ASTExplorerView.actionExamples

    // MARK: - UI State
    @State private var selectedTab = 0
    @State private var actions: VPLLayerConceptOrderedSet = Self.examples[0].set
    @State private var syntaxView: SyntaxView?
    @State private var swiftUICodeString: String = ""
    @State private var errorMessage: String?

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            Text("Actions → Syntax → Code")
                .font(.title2).bold()

            Button("Generate") { self.generate() }
                .buttonStyle(.borderedProminent)

            if let error = self.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            TabView(selection: $selectedTab) {
                ForEach(Self.examples.indices, id: \.self) { idx in
                    tabContent(for: idx)
                        .tabItem { Text(Self.examples[idx].title) }
                        .tag(idx)
                }
            }
            .tabViewStyle(.automatic)
            .onAppear { loadExample(0) }
            .onChange(of: selectedTab) { loadExample($0) }
        }
        .padding()
    }

    // MARK: - Single‑tab layout
    @ViewBuilder
    private func tabContent(for idx: Int) -> some View {
        HStack(spacing: 18) {
            // Editable StitchActions JSON
            VStack(alignment: .leading) {
                Text("Actions").font(.headline)
                Text("\(self.actions)")
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary)
                Spacer()
            }

            // Parsed SyntaxView
            VStack(alignment: .leading) {
                Text("Syntax").font(.headline)
                ScrollView {
                    if let node = self.syntaxView {
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

            // Generated SwiftUI code
            VStack(alignment: .leading) {
                Text("Code").font(.headline)
                ScrollView {
                    if self.swiftUICodeString.isEmpty {
                        Text("—")
                    } else {
                        Text(self.swiftUICodeString)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .border(Color.secondary)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Helpers
    private func generate() {
        // Reset
        self.errorMessage = nil
        self.syntaxView = nil
        self.swiftUICodeString = ""

        guard let node = SyntaxView.build(from: self.actions) else {
            self.errorMessage = "Failed to build SyntaxView from actions."
            return
        }

        self.syntaxView = node
        self.swiftUICodeString = swiftUICode(from: node)
    }

    private func loadExample(_ idx: Int) {
        self.actions = Self.examples[idx].set
        self.generate()
    }
}

#if DEBUG
struct ActionsToSyntaxToCodeExploratoryView_Previews: PreviewProvider {
    static var previews: some View {
        ActionsToSyntaxToCodeExploratoryView()
            .frame(minWidth: 1200, minHeight: 800)
    }
}
#endif
