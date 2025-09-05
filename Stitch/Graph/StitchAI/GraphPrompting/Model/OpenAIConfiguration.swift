//
//  OpenAIConfiguration.swift
//  Stitch
//
//  Created by Claude on 8/14/25.
//

import Foundation

enum OpenAIModel: String, CaseIterable, Identifiable {
    case gpt5 = "gpt-5-2025-08-07"
    case gpt5Mini = "gpt-5-mini-2025-08-07"
    case gpt5Nano = "gpt-5-nano-2025-08-07"
    case o4Mini = "o4-mini-2025-04-16"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gpt5:
            return "GPT-5"
        case .gpt5Mini:
            return "GPT-5 Mini"
        case .gpt5Nano:
            return "GPT-5 Nano"
        case .o4Mini:
            return "O4 Mini"
        }
    }
    
    static var `default`: OpenAIModel { .gpt5 }
}

enum OpenAIVerbosity: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    static var `default`: OpenAIVerbosity { .low }
}

enum OpenAIReasoningEffort: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    static var `default`: OpenAIReasoningEffort { .medium }
}

// Model-specific parameter validation
struct OpenAIModelConstraints {
    static func validateVerbosity(for model: OpenAIModel, requestedVerbosity: String) -> OpenAIVerbosity {
        switch model {
        case .o4Mini:
            // O4 models only support "medium" verbosity
            return .medium
        case .gpt5, .gpt5Mini, .gpt5Nano:
            // GPT-5 family supports all verbosity levels
            return requestedVerbosity.asOpenAIVerbosity
        }
    }
}


extension String {
    var asOpenAIModel: OpenAIModel {
        OpenAIModel(rawValue: self) ?? .default
    }
    
    var asOpenAIVerbosity: OpenAIVerbosity {
        OpenAIVerbosity(rawValue: self) ?? .default
    }
    
    var asOpenAIReasoningEffort: OpenAIReasoningEffort {
        OpenAIReasoningEffort(rawValue: self) ?? .default
    }
}
