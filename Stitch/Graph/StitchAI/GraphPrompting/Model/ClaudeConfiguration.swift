//
//  ClaudeAlternative.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/14/25.
//

import SwiftUI


// MARK: - Claude Model Configuration

enum ClaudeModel: String, CaseIterable, Identifiable {
    case claude35Haiku = "claude-3-5-haiku-20241022"
    case claude37Sonnet = "claude-3-7-sonnet-20250219"
    case claude4Sonnet = "claude-sonnet-4-20250514"
    case claude4Opus = "claude-opus-4-20250514"
    case claude41Opus = "claude-opus-4-1-20250805"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .claude35Haiku:
            return "Claude 3.5 Haiku"
        case .claude37Sonnet:
            return "Claude 3.7 Sonnet"
        case .claude4Sonnet:
            return "Claude 4 Sonnet"
        case .claude4Opus:
            return "Claude 4 Opus"
        case .claude41Opus:
            return "Claude 4.1 Opus"
        }
    }
    
    static var `default`: ClaudeModel { .claude35Haiku }
    
    var supportsThinking: Bool {
        switch self {
        case .claude4Opus, .claude41Opus, .claude4Sonnet, .claude37Sonnet:
            return true
        case .claude35Haiku:
            return false
        }
    }
    
    /// Maximum output tokens allowed for this model
    var maxTokens: Int {
        switch self {
        case .claude41Opus:
            return 32000  // Claude 4.1 Opus limit
        case .claude4Opus:
            return 32768  // Claude 4 Opus limit
        case .claude4Sonnet:
            return 32768  // Claude 4 Sonnet limit  
        case .claude37Sonnet:
            return 32768  // Claude 3.7 Sonnet limit
        case .claude35Haiku:
            return 8192  // Claude 3.5 Haiku limit
        }
    }
}

extension String {
    var asClaudeModel: ClaudeModel {
        ClaudeModel(rawValue: self) ?? .default
    }
}
