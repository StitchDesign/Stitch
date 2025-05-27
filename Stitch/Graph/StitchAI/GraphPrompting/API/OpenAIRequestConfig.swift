//
//  OpenAIRequestConfig.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/22/25.
//

import Foundation

/// Configuration settings for OpenAI API requests
struct OpenAIRequestConfig: Equatable, Hashable {
    let maxRetries: Int        // Maximum number of retry attempts for failed requests
    let timeoutInterval: TimeInterval   // Request timeout duration in seconds
    let retryDelay: TimeInterval       // Delay between retry attempts
    let maxTimeoutErrors: Int  // Maximum number of timeout errors before showing alert
    
    /// Default configuration with optimized retry settings
    static let `default` = OpenAIRequestConfig(
        maxRetries: 3,
        timeoutInterval: FeatureFlags.STITCH_AI_REASONING ? 180 : 60,
        retryDelay: 2,
        maxTimeoutErrors: 4
    )
}
