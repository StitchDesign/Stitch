//
//  OpenAIRequestHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/7/25.
//

import Foundation

/// Configuration settings for OpenAI API requests
struct OpenAIRequestConfig {
    let maxRetries: Int        // Maximum number of retry attempts for failed requests
    let timeoutInterval: TimeInterval   // Request timeout duration in seconds
    let retryDelay: TimeInterval       // Delay between retry attempts
    let maxTimeoutErrors: Int  // Maximum number of timeout errors before showing alert
    let stream: Bool           // Whether to stream the response
    
    /// Default configuration with optimized retry settings
    static let `default` = OpenAIRequestConfig(
        maxRetries: 3,
        timeoutInterval: 60,
        retryDelay: 2,
        maxTimeoutErrors: 4,
        stream: true
    )
}



// Note: an event is usually not a long-lived data structure; but this is used for retry attempts.
/// Main event handler for initiating OpenAI API requests
struct OpenAIRequest {
    private let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    let prompt: String             // User's input prompt
    let systemPrompt: String       // System-level instructions loaded from file
    let config: OpenAIRequestConfig // Request configuration settings
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default,
         graph: GraphState) throws {
        self.prompt = prompt
        self.config = config
        
        // Load system prompt from bundled file
        let loadedPrompt = try StitchAIManager.systemPrompt(graph: graph)
        self.systemPrompt = loadedPrompt
    }
}
