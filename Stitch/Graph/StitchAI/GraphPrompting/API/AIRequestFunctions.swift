//
//  AIRequestFunctions.swift
//  Stitch
//
//  Created by Claude Code on 9/5/25.
//

import Foundation
import SwiftUI

// MARK: - Provider-agnostic AI Request Function

/// Provider-agnostic orchestrator function
@MainActor
func makeAIRequest(
    previewWindowPrompt: String,
    userPrompt: String,
    base64Image: String?,
    openAIAPIKey: String,
    openAIModel: OpenAIModel,
    claudeModel: ClaudeModel,
    verbosity: OpenAIVerbosity,
    reasoningEffort: OpenAIReasoningEffort,
    document: StitchDocumentViewModel
) async throws -> String {
    
    let provider = AIProviderConfig.shared.currentProvider
    log("🔥 DEBUG: makeAIRequest using provider: \(provider.displayName)")
    log("makeAIRequest: Using provider: \(provider.displayName)")
    
    switch provider {
    case .openAI:
        return try await makeOpenAIStreamingRequest(
            userPrompt: userPrompt,
            base64Image: base64Image,
            openAIAPIKey: openAIAPIKey,
            model: openAIModel,
            verbosity: verbosity,
            reasoningEffort: reasoningEffort,
            document: document
        )
    case .claude:
        return try await makeClaudeStreamingRequest(
            previewWindowPrompt: previewWindowPrompt,
            userPrompt: userPrompt,
            base64Image: base64Image,
            model: claudeModel,
            document: document
        )
    }
}
