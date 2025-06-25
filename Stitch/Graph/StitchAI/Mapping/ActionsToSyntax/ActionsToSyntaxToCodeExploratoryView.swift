//
//  ActionsToSyntaxToCodeExploratoryView.swift
//  Stitch
//
//  Created by ChatGPT on 6/24/25.
//

import SwiftUI

/// Playground view that lets you:
/// 1. Paste or edit a JSON array of StitchActions (`VPLLayerConceptOrderedSet`),
/// 2. Convert them into a `SyntaxView`,
/// 3. Generate the equivalent SwiftUI source code – all side‑by‑side.
struct ActionsToSyntaxToCodeExploratoryView: View {

    static let demoLayerId = UUID()
    
    // MARK: - UI State
    @State private var actionsText: String = "[]"        // editable JSON
    @State private var actions: VPLLayerConceptOrderedSet = [
        .layer(.init(id: Self.demoLayerId, name: .rectangle, children: [])),
        .layerInputSet(.init(id: Self.demoLayerId, input: .color, value: "Color.red")),
        .layerInputSet(.init(id: Self.demoLayerId, input: .opacity, value: "0.5")),
        .layerInputSet(.init(id: Self.demoLayerId, input: .scale, value: "2")),
    ]
    @State private var syntaxView: SyntaxView?
    @State private var swiftUICodeString: String = ""
    @State private var errorMessage: String?

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            Text("StitchActions → ViewNode → SwiftUI code")
                .font(.title2).bold()

            Button("Generate") { self.generate() }
                .buttonStyle(.borderedProminent)

            if let error = self.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

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
        .padding()
        .onAppear {
            self.generate()
        }
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
}

#if DEBUG
struct ActionsToSyntaxToCodeExploratoryView_Previews: PreviewProvider {
    static var previews: some View {
        ActionsToSyntaxToCodeExploratoryView()
            .frame(minWidth: 1200, minHeight: 800)
    }
}
#endif
