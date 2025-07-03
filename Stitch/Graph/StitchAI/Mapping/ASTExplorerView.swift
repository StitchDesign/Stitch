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
    @State private var stitchActions: [CurrentAIPatchBuilderResponseFormat.LayerData] = []
    @State private var rebuiltSyntax: [SyntaxView] = []
    @State private var regeneratedCode: String = ""
    @State private var errorString: String?
    @State private var silentlyCaughtErrors: [SwiftUISyntaxError] = []

    /// Controls which columns are visible.  Defaults to showing all.
    @State private var visibleStages: Set<Stage> = Set(Stage.allCases)

    init(
//        initialVisibleStages: Set<Stage> = Set(Stage.allCases)
        initialVisibleStages: Set<Stage> = Set([.originalCode, .parsedSyntax, .derivedActions])
    ) {
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
            .onChange(of: selectedTab, initial: true) { _, _ in transform() }
            
            if let errorString = errorString {
                VStack(alignment: .leading) {
                    Text("Thrown Error")
                        .font(.headline)
                    
                    HStack {
                        Text(errorString)
                            .monospaced()
                            .padding()
                        Spacer()
                    }
                    .border(Color.secondary)
                }
                .padding(.bottom)
            }
            
            if !self.silentlyCaughtErrors.isEmpty {
                VStack(alignment: .leading) {
                    Text("Silently Caught Unsupported Concepts")
                        .font(.headline)
                    
                    HStack {
                        Text(try! self.silentlyCaughtErrors.map { "\($0)" }
                                    .encodeToPrintableString())
                            .monospaced()
                            .padding()
                        Spacer()
                    }
                    .border(Color.secondary)
                }
                .padding(.bottom)
            }
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
                    stageView(
                        title: Stage.originalCode.title,
                        text: codes[idx],
                        isEditor: true,
                        editorBinding: binding
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                    
                case .parsedSyntax:
                    stageView(
                        title: Stage.parsedSyntax.title,
                        text: firstSyntax.map { formatSyntaxView($0) } ?? "—"
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                    
                case .derivedActions:
                    stageView(
                        title: Stage.derivedActions.title,
                        text: (try? stitchActions.encodeToPrintableString()) ?? "—"
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                    
                case .rebuiltSyntax:
                    stageView(
                        title: Stage.rebuiltSyntax.title,
                        text: rebuiltSyntax.reduce(into: "") { stringBuilder, syntax in
                            stringBuilder += "\n\(formatSyntaxView(syntax))"
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                    
                case .regeneratedCode:
                    stageView(
                        title: Stage.regeneratedCode.title,
                        text: regeneratedCode.isEmpty ? "—" : regeneratedCode
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                }
            }
        }
    }

    // MARK: Helpers
    private func transform() {
        let currentCode = codes[selectedTab]

        // Reset all values
        firstSyntax = nil
        stitchActions = []
        rebuiltSyntax = []
        regeneratedCode = ""
        errorString = nil
        silentlyCaughtErrors = []

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(currentCode)
        
        // Parse code → Syntax
        guard let syntax = codeParserResult.rootView else {
            return
        }
        firstSyntax = syntax
        
        silentlyCaughtErrors += codeParserResult.caughtErrors

        do {
            // Syntax → Actions
            let stitchActionsResult = try syntax.deriveStitchActions()
            
            stitchActions = stitchActionsResult.actions
            silentlyCaughtErrors += stitchActionsResult.caughtErrors
            
            // Actions → Syntax
            rebuiltSyntax = try SyntaxView.build(from: stitchActions)
            
            // Syntax → Code
            regeneratedCode = rebuiltSyntax.reduce(into: "") { result, node in
                let codeString = swiftUICode(from: node)
                result += "\n\(codeString)"
            }
        } catch {
            errorString = "\(error)"
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
                    .onChange(of: binding.wrappedValue, initial: true) { _,_  in transform() }
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: – Pretty‑printing helpers for VPL actions
private extension CurrentAIPatchBuilderResponseFormat.LayerData? {

    /// Pretty‑printed JSON with the nested `{ "orientation": { } }`
    /// (or `{ "bool": { } }`, etc.) collapsed to a single string value so the
    /// result is easier for humans to scan.
    var humanReadable: String {
        // Convert `nil` to a dash
        guard let layerData = self else { return "—" }

        // 1) Encode the real structure
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let rawData = try? encoder.encode(layerData),
              var json = String(data: rawData, encoding: .utf8) else {
            return "—"
        }

        // 2) Collapse `"value_type" : { "foo" : { } }` → `"value_type" : "foo"`
        let pattern = #"\"value_type\"\s*:\s*\{\s*\"([^\"]+)\"\s*:\s*\{\s*\}\s*\}"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let fullRange = NSRange(location: 0, length: json.utf16.count)
            json = regex.stringByReplacingMatches(in: json,
                                                  options: [],
                                                  range: fullRange,
                                                  withTemplate: "\"value_type\" : \"$1\"")
        }

        return json
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
