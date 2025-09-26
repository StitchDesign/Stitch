//
//  StitchAITrainingDataInspectionOverlay.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/29/25.
//

import Foundation
import SwiftUI


// MARK: THIS VIEW IS ONLY FOR VIEWING AI-TRAINING DATA, A JSON ARRAY OF JSON OBJECTS LIKE { `user_prompt`, `generated_code` }

// MARK: - Data Models

struct StitchAITrainingDatum: Codable, Identifiable {
    let id = UUID()
    let userPrompt: String
    let generatedCode: String
    
    private enum CodingKeys: String, CodingKey {
        case userPrompt = "user_prompt"
        case generatedCode = "generated_code"
    }
}

// MARK: - Data Loader

class StitchAITrainingDataLoader: ObservableObject {
    @Published var examples: [StitchAITrainingDatum] = []
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
            examples = try decoder.decode([StitchAITrainingDatum].self, from: data)
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

struct StitchAITrainingDataCodeCreator: StitchAICodeCreator {
    let id: UUID = UUID()
    
    let preGeneratedCode: String
    
    init(generatedCode: String) {
        self.preGeneratedCode = generatedCode
    }
    
    // Skip OpenAI call - just return the pre-generated code
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager) async throws -> String {
        log("StitchAIExampleCodeCreator: using pre-generated code")
        return preGeneratedCode
    }
}

// MARK: - UI Components

struct StitchAITrainingDataInspectionOverlay: View {
    @StateObject private var loader = StitchAITrainingDataLoader()
    @Bindable var document: StitchDocumentViewModel
    @State private var customCodeInput: String = ""
    @State private var deletedPrompts: [String] = []
    
    private var isExpanded: Bool {
        document.showAITrainingExamplesOverlay
    }
    
    private let panelWidth: CGFloat = 400
    
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
                                document.showAITrainingExamplesOverlay = false
                            }
                        }
                        .font(.title2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
                            LazyVStack(alignment: .leading, spacing: 12) {
                                // Deleted prompts section
                                if !deletedPrompts.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Deleted Prompts:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Button("Clear All") {
                                                deletedPrompts.removeAll()
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(deletedPrompts, id: \.self) { prompt in
                                                Text(prompt)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    Divider()
                                        .padding(.horizontal, 20)
                                }
                                
                                // Custom code input section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Paste Custom Code:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    TextEditor(text: $customCodeInput)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(height: 100)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                    
                                    Button("Apply Custom Code") {
                                        applyCustomCode()
                                    }
                                    .disabled(customCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 20)
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                Text("Examples:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 20)
                                
                                ForEach(loader.examples) { example in
                                    StitchAIExampleRowView(
                                        example: example,
                                        onTap: { 
                                            applyExample(example)
                                        },
                                        onDelete: {
                                            deleteExample(example)
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical)
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
    
    private func applyExample(_ example: StitchAITrainingDatum) {
        log("Applying AI graph example: \(example.userPrompt)")
        applyGeneratedCode(example.generatedCode, userPrompt: example.userPrompt)
    }
    
    private func applyCustomCode() {
        let code = customCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        
        log("Applying custom pasted code")
        applyGeneratedCode(code, userPrompt: "Custom pasted code")
    }
    
    private func deleteExample(_ example: StitchAITrainingDatum) {
        log("Deleting AI graph example: \(example.userPrompt)")
        
        // Add prompt to deleted list
        deletedPrompts.append(example.userPrompt)
        
        // Remove from examples list
        loader.examples.removeAll { $0.id == example.id }
    }
    
    private func applyGeneratedCode(_ generatedCode: String, userPrompt: String) {
        Task {
            do {
                guard let aiManager = document.aiManager else {
                    log("No AI manager available")
                    return
                }
                
                let codeCreator = StitchAITrainingDataCodeCreator(generatedCode: generatedCode)
                
                // Reuse existing processRequest flow
                let dataGlossaryPrompt = try StitchAIManager
                    .stitchAIDataGlossarySystemPrompt(graph: document.visibleGraph)
                
                let actionsResult = try await codeCreator
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager)
                
                await MainActor.run {
                    actionsResult
                        .applyAIGraph(to: document,
                                      viewStatePatchConnections: actionsResult.graphData.viewStatePatchConnections,
                                      isStreaming: false)
                }
                
                // Clear custom code input after successful application
                await MainActor.run {
                    if userPrompt == "Custom pasted code" {
                        customCodeInput = ""
                    }
                }
                
                log("Successfully applied generated code")
                
            } catch {
                log("Error applying generated code: \(error)")
                // TODO: Could show error to user here
            }
        }
    }
}

struct StitchAIExampleRowView: View {
    let example: StitchAITrainingDatum
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
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
                .background(isHovering ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1.0 : 0.3)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
