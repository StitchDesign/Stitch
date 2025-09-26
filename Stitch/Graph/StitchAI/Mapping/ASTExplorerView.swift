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
import StitchSchemaKit

// MARK: - SwiftSyntaxActionsResult Formatting

/// Formats a SwiftSyntaxActionsResult into a readable string representation for display
func formatSwiftSyntaxActionsResult(_ result: SwiftSyntaxActionsResult?, indent: String = "") -> String {
    guard let result = result else { return "nil" }

    var output = "\(indent)SwiftSyntaxActionsResult(\n"

    // Format GraphData
    output += "\(indent)  graphData: GraphData(\n"
    output += "\(indent)    layer_data_list: [\n"

    for (index, layer) in result.graphData.layer_data_list.enumerated() {
        output += formatLayerData(layer, indent: indent + "      ")
        if index < result.graphData.layer_data_list.count - 1 {
            output += ","
        }
        output += "\n"
    }

    output += "\(indent)    ],\n"
    output += "\(indent)    patchNodes: [\n"

    for (index, patch) in result.graphData.patchNodes.enumerated() {
        output += "\(indent)      \(patch.id.uuidString.prefix(8))... (\(patch.nodeTypeEntity))"
        if index < result.graphData.patchNodes.count - 1 {
            output += ","
        }
        output += "\n"
    }

    output += "\(indent)    ],\n"
    output += "\(indent)    viewStatePatchConnections: \(result.graphData.viewStatePatchConnections.isEmpty ? "[:]" : "[\(result.graphData.viewStatePatchConnections.count) connections]")\n"
    output += "\(indent)  ),\n"

    // Format caught errors
    output += "\(indent)  caughtErrors: [\n"
    for (index, error) in result.caughtErrors.enumerated() {
        output += "\(indent)    \(error)"
        if index < result.caughtErrors.count - 1 {
            output += ","
        }
        output += "\n"
    }
    output += "\(indent)  ]\n"
    output += "\(indent))"

    return output
}

/// Formats a LayerData into a readable string representation
func formatLayerData(_ layer: CurrentAIGraphData.LayerData, indent: String = "") -> String {
    var output = "\(indent)LayerData(\n"
    output += "\(indent)  node_id: \"\(layer.node_id.prefix(8))...\",\n"
    output += "\(indent)  suggested_title: \(layer.suggested_title?.description ?? "nil"),\n"
    output += "\(indent)  node_name: .\(layer.node_name.value),\n"

    if let children = layer.children, !children.isEmpty {
        output += "\(indent)  children: [\n"
        for (index, child) in children.enumerated() {
            output += formatLayerData(child, indent: indent + "    ")
            if index < children.count - 1 {
                output += ","
            }
            output += "\n"
        }
        output += "\(indent)  ],\n"
    } else {
        output += "\(indent)  children: nil,\n"
    }

    if !layer.custom_layer_input_values.isEmpty {
        output += "\(indent)  custom_layer_input_values: [\n"
        for (index, inputValue) in layer.custom_layer_input_values.enumerated() {
            output += formatLayerPortDerivation(inputValue, indent: indent + "    ")
            if index < layer.custom_layer_input_values.count - 1 {
                output += ","
            }
            output += "\n"
        }
        output += "\(indent)  ],\n"
    } else {
        output += "\(indent)  custom_layer_input_values: [],\n"
    }

    output += "\(indent)  view_events: \(layer.view_events?.description ?? "nil")\n"
    output += "\(indent))"

    return output
}

/// Formats a LayerPortDerivation into a readable string representation
func formatLayerPortDerivation(_ derivation: LayerPortDerivation, indent: String = "") -> String {
    var output = "\(indent)LayerPortDerivation(\n"
    output += "\(indent)  coordinate: LayerInputType(\n"
    output += "\(indent)    layerInput: .\(derivation.coordinate.layerInput),\n"
    output += "\(indent)    portType: .\(derivation.coordinate.portType)\n"
    output += "\(indent)  ),\n"
    output += "\(indent)  inputData: [\n"

    for (index, data) in derivation.inputData.enumerated() {
        output += formatPatchSyntaxResultType(data, indent: indent + "    ")
        if index < derivation.inputData.count - 1 {
            output += ","
        }
        output += "\n"
    }

    output += "\(indent)  ]\n"
    output += "\(indent))"

    return output
}

/// Formats a PatchSyntaxResultType into a readable string representation
func formatPatchSyntaxResultType(_ type: PatchSyntaxResultType, indent: String = "") -> String {
    switch type {
    case .node(let nodeResult):
        return "\(indent).node(\(nodeResult))"
    case .portValues(let portValuesResult):
        return "\(indent).portValues(\(portValuesResult))"
    case .portData(let connectionType):
        return "\(indent).portData(\(formatNodeConnectionType(connectionType)))"
    case .connection(let edgeData):
        return "\(indent).connection(\(edgeData))"
    case .connectionToLayerInput(let layerInput):
        return "\(indent).connectionToLayerInput(\"\(layerInput)\")"
    case .stateWrite(let stateName, let coordinate):
        return "\(indent).stateWrite(\"\(stateName)\", \(coordinate))"
    case .jsSettings(let jsResult):
        return "\(indent).jsSettings(\(jsResult))"
    }
}

/// Formats a NodeConnectionType into a readable string representation
func formatNodeConnectionType(_ connectionType: NodeConnectionType, indent: String = "") -> String {
    switch connectionType {
    case .values(let portValues):
        let formattedValues = portValues.map { formatPortValue($0) }.joined(separator: ", ")
        return ".values([\(formattedValues)])"
    case .upstreamConnection(let coordinate):
        return ".upstreamConnection(\(coordinate))"
    }
}

/// Formats a PortValue into a readable string representation
func formatPortValue(_ portValue: PortValue) -> String {
    switch portValue {
    case .bool(let value):
        return ".bool(\(value))"
    case .string(let value):
        return ".string(\"\(value)\")"
    case .number(let value):
        return ".number(\(value))"
    case .size(let size):
        return ".size(width: \(size.width), height: \(size.height))"
    case .position(let position):
        return ".position(x: \(position.x), y: \(position.y))"
    case .orientation(let orientation):
        return ".orientation(.\(orientation))"
    case .color(let color):
        return ".color(\(color))"
    default:
        return ".\(String(describing: portValue).components(separatedBy: "(").first ?? "unknown")"
    }
}

// MARK: - StrictSyntaxView Formatting

/// Formats a StrictSyntaxView into a readable string representation for display
func formatStrictSyntaxView(_ node: StrictSyntaxView, indent: String = "") -> String {
    var result = "\(indent)StrictSyntaxView("
    result += "\n\(indent)    constructor: \(String(describing: node.constructor)),"
    
    // Format modifiers
    let modifiersString = node.modifiers.isEmpty ? "[]" : node.modifiers.map { String(describing: $0) }.joined(separator: ", ")
    result += "\n\(indent)    modifiers: [\(modifiersString)],"
    
    // Format children
    if node.children.isEmpty {
        result += "\n\(indent)    children: [],"
    } else {
        result += "\n\(indent)    children: ["
        for child in node.children {
            result += "\n\(formatStrictSyntaxView(child, indent: indent + "        ")),"
        }
        result += "\n\(indent)    ],"
    }
    
    result += "\n\(indent)    id: \(node.id.uuidString.prefix(8))..."
    result += "\n\(indent))"
    
    return result
}


/// Playground that shows the *full* Stitch round‑trip.
/// You type SwiftUI code → it is parsed into `SyntaxView` → converted
/// to `StitchActions` → rebuilt back into a `SyntaxView` → and then
/// rendered as regenerated SwiftUI source.  All five stages are displayed
/// side‑by‑side so you can visually verify loss‑/faithfulness.
struct ASTExplorerView: View {

    /// Which transformation stages should be displayed.
    enum Stage: CaseIterable, Hashable {
        case originalCode, parsedSyntax, derivedActions, regeneratedCode

        /// User‑facing title for each stage.
        var title: String {
            switch self {
            case .originalCode:      return "Original SwiftUI code"
            case .parsedSyntax:      return "Parsed SyntaxView"
            case .derivedActions:    return "Derived StitchActions"
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
    @State private var firstSyntax: [SyntaxView] = []
    @State private var stitchActions: SwiftSyntaxActionsResult?
    @State private var regeneratedCode: String = ""
    @State private var errorString: String?
    @State private var silentlyCaughtErrors: [SwiftUISyntaxError] = []

    /// Controls which columns are visible.  Defaults to showing all.
    @State private var visibleStages: Set<Stage> = Set(Stage.allCases)
    
    /// Controls whether regenerated code uses PortValueDescription format
    @State private var usePortValueDescription: Bool = false
    
    /// Controls whether to generate raw view code or full SwiftUI file with ContentView wrapper
    @State private var ignoreScript: Bool = false

    init(
//        initialVisibleStages: Set<Stage> = Set(Stage.allCases)
//        initialVisibleStages: Set<Stage> = Set([.originalCode, .parsedSyntax, .derivedActions])
//        initialVisibleStages: Set<Stage> = Set([.originalCode, .parsedSyntax, .derivedActions, .rebuiltSyntax])
        initialVisibleStages: Set<Stage> = Set([.originalCode, .derivedActions, .regeneratedCode])
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

            HStack(spacing: 16) {
                Button("Transform") { transform() }
                    .buttonStyle(.borderedProminent)
                
                Toggle("Use PortValueDescription", isOn: $usePortValueDescription)
                    .toggleStyle(.switch)
                    .onChange(of: usePortValueDescription) { _, _ in transform() }
                
                Toggle("Ignore Script Wrapper", isOn: $ignoreScript)
                    .toggleStyle(.switch)
                    .onChange(of: ignoreScript) { _, _ in transform() }
            }

            TabView(selection: $selectedTab) {
                ForEach(Self.examples.indices, id: \.self) { idx in
                    roundTripLayout(for: idx)
                        .tabItem { Text(Self.examples[idx].title) }
                        .tag(idx)
                }
            }
            .tabViewStyle(.automatic)
            .onChange(of: selectedTab) { _, _ in transform() }
            
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
                        text: firstSyntax
                            .map { formatSyntaxView($0) }
                            .joined(separator: "\n")
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                    
                case .derivedActions:
                    stageView(
                        title: Stage.derivedActions.title,
                        text: formatSwiftSyntaxActionsResult(stitchActions)
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
        let fakeDoc = StitchDocumentViewModel.createEmpty()
        let currentCode = codes[selectedTab]

        // Reset all values
        firstSyntax = []
        stitchActions = nil
        regeneratedCode = ""
        errorString = nil
        silentlyCaughtErrors = []

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(currentCode)
        
        // Parse code → Syntax
        firstSyntax = codeParserResult.viewStack
        
        // Apply AI result to fake document
        Task(priority: .high) {
            // Syntax → Actions
            let stitchActionsResult = try await codeParserResult.deriveStitchActions(
                bindingDeclarations: codeParserResult.bindingDeclarations,
                document: fakeDoc)
            
            try await MainActor.run {
                stitchActionsResult
                    .processAIGraph(document: fakeDoc,
                                    isStreaming: false)
    
                stitchActions = stitchActionsResult
                silentlyCaughtErrors = stitchActionsResult.caughtErrors
    
                // Updates all errors
                silentlyCaughtErrors = stitchActionsResult.caughtErrors
                
                // Generate SwiftUI code with configurable script wrapper
                let newSwiftUICode = try fakeDoc.graph.createSwiftUICode(ignoreScript: ignoreScript, usePortValueDescription: usePortValueDescription)
                self.regeneratedCode = newSwiftUICode
            }
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
private extension CurrentAIGraphData.LayerData? {

    /// Pretty‑printed JSON with the nested `{ "orientation": { } }`
    /// (or `{ "bool": { } }`, etc.) collapsed to a single string value so the
    /// result is easier for humans to scan.
    var humanReadable: String {
        // Convert `nil` to a dash
        guard let layerData = self else { return "—" }

        return "\(layerData)"
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
