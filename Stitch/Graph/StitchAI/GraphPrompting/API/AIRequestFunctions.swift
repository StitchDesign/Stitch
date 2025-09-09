//
//  AIRequestFunctions.swift
//  Stitch
//
//  Created by Claude Code on 9/5/25.
//

import Foundation
import SwiftUI

// MARK: - Pure Functions for AI Requests

/// Parameters needed for any AI request
struct AIRequestParams {
    let id: UUID
    let dataGlossaryPrompt: String
    let assistantPrompt: String
    let textInput: String
    let base64Image: String?
    let secrets: Secrets
}

/// Provider-agnostic orchestrator function
@MainActor
func makeAIRequest(
    params: AIRequestParams,
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
            params: params,
            model: openAIModel,
            verbosity: verbosity,
            reasoningEffort: reasoningEffort,
            document: document
        )
    case .claude:
        return try await makeClaudeStreamingRequest(
            params: params,
            model: claudeModel,
            document: document
        )
    }
}
