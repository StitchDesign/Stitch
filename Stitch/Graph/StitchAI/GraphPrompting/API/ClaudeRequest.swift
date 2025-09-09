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

/// Extension to convert Claude responses to OpenAI format for compatibility
extension ClaudeResponse {
    
    // TODO: can we just retrieve the content message directly?
    func toOpenAIResponse() -> OpenAIResponse {
        let content = self.content.compactMap { $0.text }.joined()
        let message = OpenAIMessage(
            role: .assistant,
            content: content,
            tool_calls: nil,
            tool_call_id: nil,
            name: nil,
            refusal: nil,
            annotations: nil
        )
        
        let choice = OpenAIChoice(
            index: 0,
            message: message,
            logprobs: nil,
            finishReason: self.stopReason ?? "stop"
        )
        
        let usage = Usage(
            promptTokens: self.usage.inputTokens,
            completionTokens: self.usage.outputTokens,
            totalTokens: self.usage.inputTokens + self.usage.outputTokens,
            promptTokensDetails: TokenDetails(cachedTokens: 0, audioTokens: 0),
            completionTokensDetails: CompletionTokenDetails(
                reasoningTokens: 0,
                audioTokens: 0,
                acceptedPredictionTokens: 0,
                rejectedPredictionTokens: 0
            )
        )
        
        return OpenAIResponse(
            id: self.id,
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: self.model,
            choices: [choice],
            usage: usage,
            systemFingerprint: nil,
            serviceTier: "default"
        )
    }
}

extension StitchAIManager {
    
    // MARK: - Claude API Methods
    
    /// Execute Claude API request
    func startClaudeRequest<AIRequest>(_ request: AIRequest,
                                       attempt: Int,
                                       lastCapturedError: String,
                                       document: StitchDocumentViewModel) async -> Result<OpenAIMessage, StitchAIStreamingError> where AIRequest: StitchAIRequestable {
        
        // Check if we've exceeded retry attempts
        guard attempt <= request.config.maxRetries else {
            log("All StitchAI retry attempts exhausted", .logToServer)
            return .failure(.maxRetriesError(request.config.maxRetries,
                                             lastCapturedError))
        }
        
        guard let urlRequest = Self.getURLRequestForClaude(request: request) else {
            log("StitchAIManager: startClaudeRequest: could not get request - conversion failed", .logToServer)
            return .failure(.urlRequestCreationFailure)
        }
        
        log("StitchAIManager: startClaudeRequest: Claude request created successfully", .logToServer)
        
        let streamOpeningResult = await self.makeClaudeRequest(
            for: urlRequest,
            with: request,
            attempt: attempt,
            document: document)
        
        switch streamOpeningResult {
            
        case .success(let response):
            // Check for rate limits
            if let error = handlePossibleClaudeRateLimit(
                response: response.1,
                request: request) {
                return .failure(error)
            }
            
            return .success(response.0)
            
        case .failure(let error):
            log("StitchAIManager: startClaudeRequest: streaming error: \(error.localizedDescription)", .logToServer)
            
            // Add more detailed error logging for Claude requests
            if let httpError = error as? URLError {
                log("Claude request URLError: \(httpError.code.rawValue) - \(httpError.localizedDescription)", .logToServer)
            } else if let nsError = error as NSError? {
                log("Claude request NSError: \(nsError.domain) - \(nsError.code) - \(nsError.localizedDescription)", .logToServer)
                if let userInfo = nsError.userInfo as? [String: Any] {
                    log("Claude request error userInfo: \(userInfo)", .logToServer)
                }
            }
            
            if let error = handleClaudeStreamingError(
                error,
                attempt: attempt,
                request: request) {
                return .failure(error)
            }
            
            return .failure(.other(error))
        }
    }
    
    /// Create a URL request for Claude API
    static func getURLRequestForClaude<AIRequest>(request: AIRequest) -> URLRequest? where AIRequest: StitchAIRequestable {
        
        guard let claudeAPIKey = StitchStore.claudeAPIKey, !claudeAPIKey.isEmpty else {
            log("ERROR: Claude API key not configured in settings", .logToServer)
            return nil
        }
        
        log("Claude API Key available: true", .logToServer)
        log("Claude API Key length: \(claudeAPIKey.count)", .logToServer)
        
        let config = request.config
        let claudeURL = URL(string: AIProvider.claude.baseURL)!
        
        var urlRequest = URLRequest(url: claudeURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        log("Claude request URL: \(claudeURL)", .logToServer)
        log("Claude request headers configured", .logToServer)
        
        // Convert OpenAI-style request to Claude format
        guard let claudeBodyData = convertToClaudeRequest(request: request) else {
            log("ERROR: Failed to convert request to Claude format", .logToServer)
            return nil
        }
        
        log("Claude request body created successfully", .logToServer)
        
        urlRequest.httpBody = claudeBodyData
        return urlRequest
    }
    
    
    // TODO: CAN WE AVOID THIS?
    /// Convert OpenAI-style request to Claude format
    static func convertToClaudeRequest<AIRequest>(request: AIRequest) -> Data? where AIRequest: StitchAIRequestable {
        
        guard let payloadData = try? request.getPayloadData(),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            log("Claude conversion: Failed to get payload data")
            return nil
        }
        
        // Extract OpenAI messages
        guard let messages = payloadJSON["messages"] as? [[String: Any]] else {
            log("Claude conversion: Failed to extract messages")
            return nil
        }
        
        var claudeMessages: [[String: Any]] = []
        var systemPrompt: String? = nil
        
        // Convert messages to Claude format
        for message in messages {
            guard let role = message["role"] as? String else {
                continue
            }
            
            // Handle different content formats (string vs array for vision)
            var contentText: String = ""
            
            if let content = message["content"] as? String {
                // Regular text content
                contentText = content
            } else if let contentArray = message["content"] as? [[String: Any]] {
                // Vision content array - convert to Claude format
                var claudeContentArray: [[String: Any]] = []
                
                for contentItem in contentArray {
                    if let type = contentItem["type"] as? String {
                        if type == "text", let text = contentItem["text"] as? String {
                            claudeContentArray.append([
                                "type": "text",
                                "text": text
                            ])
                        } else if type == "image_url",
                                  let imageUrl = contentItem["image_url"] as? [String: Any],
                                  let url = imageUrl["url"] as? String {
                            
                            // Convert OpenAI image_url format to Claude format
                            if url.hasPrefix("data:") {
                                // Handle base64 data URLs (data:image/jpeg;base64,...)
                                if let range = url.range(of: "base64,") {
                                    let base64Data = String(url[range.upperBound...])
                                    let mediaType = extractMediaTypeFromDataURL(url) ?? "image/jpeg"
                                    
                                    claudeContentArray.append([
                                        "type": "image",
                                        "source": [
                                            "type": "base64",
                                            "media_type": mediaType,
                                            "data": base64Data
                                        ]
                                    ])
                                }
                            } else {
                                // Handle regular URLs
                                claudeContentArray.append([
                                    "type": "image",
                                    "source": [
                                        "type": "url",
                                        "url": url
                                    ]
                                ])
                            }
                        }
                    }
                }
                
                // For Claude, if we have multiple content items, we need to handle it differently
                if claudeContentArray.count == 1 && claudeContentArray[0]["type"] as? String == "text" {
                    // Single text content - use as string
                    contentText = claudeContentArray[0]["text"] as? String ?? ""
                } else {
                    // Multiple content items or has images - don't convert to string
                    // We'll handle this differently below for Claude messages
                    claudeMessages.append([
                        "role": role == "assistant" ? "assistant" : "user",
                        "content": claudeContentArray
                    ])
                    continue
                }
            } else {
                continue // Skip messages with unsupported content format
            }
            
            if role == "system" {
                systemPrompt = contentText
            } else {
                claudeMessages.append([
                    "role": role == "assistant" ? "assistant" : "user",
                    "content": contentText
                ])
            }
        }
        
        // Get the appropriate Claude model
        let claudeModel = getClaudeModel(for: request)
        
        var claudeRequest: [String: Any] = [
            "model": claudeModel,
            "max_tokens": payloadJSON["max_tokens"] ?? 1024,
            "messages": claudeMessages
            
            // These seem to interfere with code-gen ?
//            ,
//            "stop_sequences": ["```", "//", "/*", "Note:", "Here is", "Here's", "I'll", "Let me"],
//            "temperature": 0.1  // Lower temperature for more precise, less verbose responses
        ]
        
        if let systemPrompt = systemPrompt {
            claudeRequest["system"] = systemPrompt
        }
        
        // Add temperature if present
        if let temperature = payloadJSON["temperature"] {
            claudeRequest["temperature"] = temperature
        }
        
        // Always enable streaming for Claude (better UX + thinking support)
        claudeRequest["stream"] = true
        log("Claude request - streaming enabled by default")
        
        // Add extended thinking for supported models
        let model = getClaudeModel(for: request)
        log("Claude request - using model: \(model)")
        let supportsThinking = model.contains("sonnet-4") || 
                             model.contains("opus-4") || 
                             model.contains("sonnet-3.7") ||
                             model.contains("claude-4") ||
                             model.contains("claude-3.7")
        
        if supportsThinking {
            claudeRequest["thinking"] = [
                "type": "enabled",
                "budget_tokens": 10000  // Allow up to 10k tokens for thinking
            ]
            log("Extended thinking enabled for model: \(model) with 10k token budget")
        } else {
            log("Extended thinking not supported for model: \(model)")
        }
        
        log("Claude conversion successful for request type: \(String(describing: type(of: request)))")
        
        // Debug log the final Claude request
        if let debugData = try? JSONSerialization.data(withJSONObject: claudeRequest, options: .prettyPrinted),
           let debugString = String(data: debugData, encoding: .utf8) {
            // M
            // log("Final Claude request body:\n\(debugString)", .logToServer)
        }
        
        return try? JSONSerialization.data(withJSONObject: claudeRequest)
    }
    
    /// Get the appropriate Claude model based on user selection and request type
    static func getClaudeModel<AIRequest>(for request: AIRequest) -> String where AIRequest: StitchAIRequestable {
        // First check if user has selected a specific Claude model from the UI
        let userSelectedModel = UserDefaults.standard.string(forKey: StitchAppSettings.CLAUDE_MODEL.rawValue)
        
        if let selectedModel = userSelectedModel, !selectedModel.isEmpty {
            log("Using user-selected Claude model: \(selectedModel)", .logToServer)
            return selectedModel
        }
        // Fallback to latest Claude model with thinking support
        let defaultModel = "claude-sonnet-4-20250514"  // Claude Sonnet 4 supports extended thinking
        return defaultModel
    }
    
    /// Make Claude API request with streaming support
    func makeClaudeRequest<AIRequest>(for urlRequest: URLRequest,
                                              with request: AIRequest,
                                              attempt: Int,
                                              document: StitchDocumentViewModel) async -> Result<(OpenAIMessage, URLResponse), Error> where AIRequest: StitchAIRequestable {
        
        log("=== makeClaudeRequest called ===")
        log("Request type: \(String(describing: type(of: request)))")
        log("Attempt: \(attempt)")
        
        // Claude always uses streaming for better UX and thinking support
        log("Claude request: Routing to streaming implementation")
        let result = await makeClaudeStreamingRequest(for: urlRequest, with: request, attempt: attempt, document: document)
        log("=== makeClaudeRequest completed ===")
        return result
    }
    
    /// Make streaming Claude API request with thinking support
    @MainActor
    func makeClaudeStreamingRequest<AIRequest>(for urlRequest: URLRequest,
                                               with request: AIRequest,
                                               attempt: Int,
                                               document: StitchDocumentViewModel) async -> Result<(OpenAIMessage, URLResponse), Error> where AIRequest: StitchAIRequestable {
        
        log("=== makeClaudeStreamingRequest STARTED ===")
        log("Starting Claude streaming request with extended thinking support")
        
        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                log("Claude streaming response status: \(httpResponse.statusCode)")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    log("Claude streaming request failed with status: \(httpResponse.statusCode)")
                    return .failure(URLError(.badServerResponse))
                }
            }
            
            var accumulatedContent = ""
            var accumulatedThinking = ""
            var currentThinkingBlock: String?
            var totalUsage: ClaudeUsage?
            
            let requestStartTime = Date()
            var firstThinkingTime: Date?
            var firstContentTime: Date?
            
            for try await line in asyncBytes.lines {
                // Skip empty lines
                guard !line.isEmpty else { continue }
                
                // Parse SSE format: "data: {json}"
                let jsonString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
                
                // Handle stream completion
                if jsonString == "[DONE]" {
                    break
                }
                
                // Parse JSON event
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                let eventType = json["type"] as? String
                
                switch eventType {
                case "message_start":
                    log("Claude stream started")
                    
                case "content_block_start":
                    if let contentBlock = json["content_block"] as? [String: Any],
                       let type = contentBlock["type"] as? String {
                        if type == "thinking" {
                            log("🧠 Claude thinking block started")
                            currentThinkingBlock = ""
                            if firstThinkingTime == nil {
                                firstThinkingTime = Date()
                                let thinkingLatency = Date().timeIntervalSince(requestStartTime) * 1000
                                log("⚡ Time to first thinking: \(String(format: "%.0f", thinkingLatency))ms")
                            }
                        } else if type == "text" {
                            log("📝 Claude text content block started")
                            if firstContentTime == nil {
                                firstContentTime = Date()
                                let contentLatency = Date().timeIntervalSince(requestStartTime) * 1000
                                log("⚡ Time to first content: \(String(format: "%.0f", contentLatency))ms")
                            }
                        }
                    }
                    
                case "content_block_delta":
                    if let delta = json["delta"] as? [String: Any] {
                        if let thinkingText = delta["thinking"] as? String {
                            // This is thinking content (thinking_delta)
                            accumulatedThinking += thinkingText
                            
                            // Stream thinking to UI
                            document.streamingReasoningText = "🧠 Thinking...\n\n\(accumulatedThinking)"
                        } else if let text = delta["text"] as? String {
                            // This is regular text content (text_delta)
                            accumulatedContent += text
                            
                            // Stream content to UI (clear reasoning text once content starts)
                            if document.streamingReasoningText.contains("🧠 Thinking") {
                                document.streamingReasoningText = ""
                            }
                        }
                    }
                    
                case "content_block_stop":
                    if currentThinkingBlock != nil {
                        log("🧠 Claude thinking block completed (\(currentThinkingBlock?.count ?? 0) chars)")
                        currentThinkingBlock = nil
                    }
                    
                case "message_delta":
                    if let usage = json["usage"] as? [String: Any] {
                        totalUsage = try? JSONDecoder().decode(ClaudeUsage.self, from: JSONSerialization.data(withJSONObject: usage))
                    }
                    
                case "message_stop":
                    log("Claude stream completed")
                    let totalTime = Date().timeIntervalSince(requestStartTime) * 1000
                    log("⚡ Total stream time: \(String(format: "%.0f", totalTime))ms")
                    
                    // Monitor cache performance
                    if let usage = totalUsage {
                        await self.monitorClaudeStreamingCachePerformance(usage: usage)
                    }
                    
                default:
                    continue
                }
            }
            
            // Create final response
            let finalMessage = OpenAIMessage(
                role: .assistant,
                content: accumulatedContent,
                tool_calls: nil,
                tool_call_id: nil,
                name: nil,
                refusal: nil,
                annotations: nil
            )
            
            log("Claude streaming completed successfully")
            log("Final content length: \(accumulatedContent.count) characters")
            log("Total thinking length: \(accumulatedThinking.count) characters")
            
            return .success((finalMessage, response))
            
        } catch {
            log("Claude streaming error: \(error)")
            return .failure(error)
        }
    }
    
    /// Monitor Claude prompt cache performance from streaming usage data
    private func monitorClaudeStreamingCachePerformance(usage: ClaudeUsage) async {
        // Extract cache and usage data
        let inputTokens = usage.inputTokens
        let outputTokens = usage.outputTokens
        let cacheCreationInputTokens = usage.cacheCreationInputTokens ?? 0
        let cacheReadInputTokens = usage.cacheReadInputTokens ?? 0
        
        print("🔍 Claude Streaming Response Usage Analysis for Cache Performance:")
        print("📊 Usage Statistics:")
        print("   → Input tokens: \(inputTokens)")
        print("   → Output tokens: \(outputTokens)")
        
        // Analyze cache performance
        print("💾 Cache Performance Analysis:")
        if cacheCreationInputTokens > 0 {
            print("   ✅ Cache created with \(cacheCreationInputTokens) tokens")
            
            // Calculate potential savings
            let potentialSavings = Double(cacheCreationInputTokens) * 0.9 // 90% cost reduction for cached tokens
            print("   💰 Potential future savings: \(String(format: "%.0f", potentialSavings)) token-equivalents per request")
        }
        
        if cacheReadInputTokens > 0 {
            let cachePercentage = (Double(cacheReadInputTokens) / Double(inputTokens)) * 100
            print("   🚀 Cache hit! \(cacheReadInputTokens) tokens read from cache (\(String(format: "%.1f", cachePercentage))%)")
            
            // Calculate actual savings
            let actualSavings = Double(cacheReadInputTokens) * 0.9 // 90% cost reduction for cached tokens
            print("   💰 Cost savings: ~\(String(format: "%.0f", actualSavings)) token-equivalents")
        } else if inputTokens >= 1024 {
            print("   ❓ No cache hits detected")
            print("   → Cache may still be warming up for future requests")
        } else {
            print("   📏 Prompt too small for caching (\(inputTokens) < 1024 tokens)")
            print("   → Claude caching requires ≥1024 tokens")
            print("   → Consider consolidating static content")
        }
        
        // Log overall token usage
        let totalTokens = inputTokens + outputTokens
        print("🎯 Total usage: \(inputTokens) input + \(outputTokens) output = \(totalTokens) tokens")
        
        // Log to server for analytics
        log("Claude streaming cache performance - Created: \(cacheCreationInputTokens), Read: \(cacheReadInputTokens), Total: \(totalTokens)")
    }
    
    /// Handle Claude rate limits
    private func handlePossibleClaudeRateLimit<AIRequest>(response: URLResponse,
                                                          request: AIRequest) -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            
            if httpResponse.statusCode == 429 || // Rate limit
                httpResponse.statusCode >= 500 {  // Server error
                log("Claude Request failed with status code: \(httpResponse.statusCode)", .logToServer)
                log("Retrying in \(request.config.retryDelay) seconds")
                return .rateLimit
            }
        }
        
        return nil
    }
    
    /// Handle Claude streaming errors
    private func handleClaudeStreamingError<AIRequest>(_ error: Error,
                                                       attempt: Int,
                                                       request: AIRequest) -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        log("Claude request failed: \(error)")
        
        if let _ = (error as? CancellationError) {
            return nil // Cancellation is not an error
        }
        
        guard let error = error as NSError? else {
            return .invalidURL
        }
        
        // Handle network errors similar to OpenAI
        if error.code == NSURLErrorCancelled {
            return nil // Cancellation is not an error
        }
        else if error.code == NSURLErrorTimedOut {
            log("Claude timeout error count: \(attempt)")
            
            if attempt > request.config.maxTimeoutErrors {
                return .maxTimeouts
            } else {
                return .timeout
            }
        }
        else if error.code == NSURLErrorNotConnectedToInternet ||
                error.code == NSURLErrorNetworkConnectionLost {
            return .internetConnectionFailed
        }
        else {
            return .other(error)
        }
    }
}
