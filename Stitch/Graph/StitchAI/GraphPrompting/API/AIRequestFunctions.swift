//
//  AIRequestFunctions.swift
//  Stitch
//
//  Created by Claude Code on 9/5/25.
//

import Foundation
import SwiftUI

// MARK: - Unified AI Model Enum

/// Unified enum that represents both OpenAI and Claude models
enum AIModel {
    case openAI(OpenAIModel)
    case claude(ClaudeModel)
    
    var displayName: String {
        switch self {
        case .openAI(let model):
            return model.displayName
        case .claude(let model):
            return model.displayName
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .openAI:
            return .openAI
        case .claude:
            return .claude
        }
    }
}

// MARK: - Provider-agnostic AI Request Function

/// Provider-agnostic orchestrator function
func makeAIRequest(
    previewWindowPrompt: String,
    userPrompt: String,
    base64Image: String?,
    openAIAPIKey: String,
    model: AIModel,
    verbosity: OpenAIVerbosity,
    reasoningEffort: OpenAIReasoningEffort,
    document: StitchDocumentViewModel,
    aiManager: StitchAIManager,
    currentGraphEntity: GraphEntity,
    graphPositionAnchorPoint: CGPoint,
    groupNodeFocused: UUID?
) async throws -> String {
    switch model {
    case .openAI(let openAIModel):
        return try await makeOpenAIStreamingRequest(
            userPrompt: userPrompt,
            base64Image: base64Image,
            openAIAPIKey: openAIAPIKey,
            model: openAIModel,
            verbosity: verbosity,
            reasoningEffort: reasoningEffort,
            document: document
        )
    case .claude(let claudeModel):
        return try await aiManager.claudeStreamingActor
            .makeClaudeStreamingRequest(
                previewWindowPrompt: previewWindowPrompt,
                userPrompt: userPrompt,
                base64Image: base64Image,
                model: claudeModel,
                document: document,
                currentGraphEntity: currentGraphEntity,
                graphPositionAnchorPoint: graphPositionAnchorPoint,
                groupNodeFocused: groupNodeFocused
            )
    }
}
