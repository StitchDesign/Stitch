//
//  ClaudeAlternative.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/14/25.
//

import SwiftUI


// MARK: - Claude Model Configuration

enum ClaudeModel: String, CaseIterable, Identifiable {
    case claude4Sonnet = "claude-sonnet-4-20250514"
    case claude45Sonnet = "claude-sonnet-4-5-20250929"
    case claude41Opus = "claude-opus-4-1-20250805"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude4Sonnet:
            return "Claude Sonnet 4"
        case .claude45Sonnet:
            return "Claude Sonnet 4.5"
        case .claude41Opus:
            return "Claude Opus 4.1"
        }
    }

    static var `default`: ClaudeModel { .claude45Sonnet }

    var supportsThinking: Bool {
        switch self {
        case .claude41Opus, .claude4Sonnet, .claude45Sonnet:
            return true
        }
    }

    /// Maximum output tokens allowed for this model
    var maxTokens: Int {
        switch self {
        case .claude41Opus:
            return 32000  // Claude 4.1 Opus limit
        case .claude4Sonnet:
            return 32768  // Claude 4 Sonnet limit
        case .claude45Sonnet:
            return 32768  // Claude 4.5 Sonnet limit
        }
    }
}

extension String {
    var asClaudeModel: ClaudeModel {
        ClaudeModel(rawValue: self) ?? .default
    }
}
