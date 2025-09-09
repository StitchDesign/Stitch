//
//  ClaudeRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/14/25.
//

import SwiftUI


// NOTE: MUCH OF THIS CODE IS A 'FIRST PASS' THAT LETS US TEST OUT ANTHROPIC MODELS.
// DOWN THE ROAD WE LIKELY WANT TO CLEAN AND CONSOLIDATE (OR AT LEAST RENAME) THE OPEN-AI VS ANTHROPIC PIPELINES.

// MARK: - Claude Response Types

/// Represents the complete response structure from Claude's API
struct ClaudeResponse: Codable {
    var id: String
    var type: String
    var role: String
    var content: [ClaudeContent]
    var model: String
    var stopReason: String?
    var stopSequence: String?
    var usage: ClaudeUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

/// Represents content in Claude's response
struct ClaudeContent: Codable {
    var type: String
    var text: String?
}

/// Tracks token usage metrics for Claude API requests, including caching information
struct ClaudeUsage: Codable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationInputTokens: Int?
    var cacheReadInputTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}
