//
//  GeneratedCodeInspectionView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/29/25.
//

import Foundation
import SwiftUI

// MARK: - Data Models

struct StitchAIGraphExample: Codable, Identifiable {
    let id = UUID()
    let userPrompt: String
    let generatedCode: String
    
    private enum CodingKeys: String, CodingKey {
        case userPrompt = "user_prompt"
        case generatedCode = "generated_code"
    }
}

// MARK: - Data Loader

class StitchAIExamplesLoader: ObservableObject {
    @Published var examples: [StitchAIGraphExample] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func loadExamples() {
        guard let url = Bundle.main.url(forResource: "stitch_examples_with_generated_code", withExtension: "json") else {
            error = "Could not find examples JSON file in app bundle"
            return
        }
        
        isLoading = true
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            examples = try decoder.decode([StitchAIGraphExample].self, from: data)
            isLoading = false
            log("Successfully loaded \(examples.count) AI graph examples")
        } catch {
            self.error = "Failed to load examples: \(error.localizedDescription)"
            isLoading = false
            log("Error loading AI graph examples: \(error)")
        }
    }
}

// MARK: - AI Code Creator

struct StitchAIExampleCodeCreator: StitchAICodeCreator {
    let id: UUID = UUID()
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt
    
    let preGeneratedCode: String
    
    init(generatedCode: String) {
        self.preGeneratedCode = generatedCode
    }
    
    // Skip OpenAI call - just return the pre-generated code
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    dataGlossaryPrompt: String) async throws -> String {
        log("StitchAIExampleCodeCreator: using pre-generated code")
        return preGeneratedCode
    }
}

// MARK: - UI Components

struct GeneratedCodeInspectionView: View {
    @StateObject private var loader = StitchAIExamplesLoader()
    @Bindable var document: StitchDocumentViewModel
    
    private var isExpanded: Bool {
        document.showAIExamples
    }
    
    private let panelWidth: CGFloat = 320
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("AI Examples")
                            .font(.headline)
                            .padding(.leading)
                        Spacer()
                        Button("×") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                document.showAIExamples = false
                            }
                        }
                        .font(.title2)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // Content
                    if loader.isLoading {
                        VStack {
                            ProgressView("Loading examples...")
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if let error = loader.error {
                        VStack {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(loader.examples) { example in
                                    StitchAIExampleRowView(
                                        example: example,
                                        onTap: { 
                                            applyExample(example)
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
                .frame(width: panelWidth)
                .background(Color(.systemBackground))
                .transition(.move(edge: .leading))
            }
            
            Spacer()
        }
        .overlay(alignment: .leading) {
            // Toggle button (will be handled by topbar buttons instead)
            EmptyView()
        }
        .onAppear {
            loader.loadExamples()
        }
    }
    
    private func applyExample(_ example: StitchAIGraphExample) {
        log("Applying AI graph example: \(example.userPrompt)")
        
        Task {
            do {
                guard let aiManager = document.aiManager else {
                    log("No AI manager available")
                    return
                }
                
                let codeCreator = StitchAIExampleCodeCreator(generatedCode: example.generatedCode)
                
                // Reuse existing processRequest flow
                let dataGlossaryPrompt = try StitchAIManager
                    .stitchAIDataGlossarySystemPrompt(graph: document.visibleGraph)
                
                var actionsResult = try await codeCreator
                    .processRequest(userPrompt: example.userPrompt,
                                    document: document,
                                    aiManager: aiManager,
                                    dataGlossaryPrompt: dataGlossaryPrompt)
                
                await MainActor.run {
                    Task(priority: .high) {
                        await actionsResult
                            .applyAIGraph(to: document,
                                          viewStatePatchConnections: actionsResult.graphData.viewStatePatchConnections,
                                          requestType: StitchAIExampleCodeCreator.type)
                    }
                }
                
                // Close panel after successful application
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        document.showAIExamples = false
                    }
                }
                
                log("Successfully applied AI graph example")
                
            } catch {
                log("Error applying AI graph example: \(error)")
                // TODO: Could show error to user here
            }
        }
    }
}

struct StitchAIExampleRowView: View {
    let example: StitchAIGraphExample
    let onTap: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(example.userPrompt)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Tap to apply")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
//            .background(isHovering ? Color(NSColor.controlAccentColor).opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
