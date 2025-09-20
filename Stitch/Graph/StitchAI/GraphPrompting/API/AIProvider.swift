//
//  AIProvider.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/14/25.
//

import SwiftUI


// MARK: - AI Provider Configuration

/// Enum representing the available AI providers
enum AIProvider: String, CaseIterable, Codable {
    case openAI = "openai"
    case claude = "claude"
    
    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .claude:
            return "Claude"
        }
    }
    
    var baseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .claude:
            return "https://api.anthropic.com/v1/messages"
        }
    }
}
