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

/// Tracks token usage metrics for Claude API requests
struct ClaudeUsage: Codable {
    var inputTokens: Int
    var outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// Extension to convert Claude responses to OpenAI format for compatibility
extension ClaudeResponse {
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
        
        guard let urlRequest = Self.getURLRequestForClaude(request: request,
                                                           secrets: self.secrets) else {
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
    static func getURLRequestForClaude<AIRequest>(request: AIRequest,
                                                  secrets: Secrets) -> URLRequest? where AIRequest: StitchAIRequestable {
        
        guard let claudeAPIKey = secrets.claudeAPIKey, !claudeAPIKey.isEmpty else {
            log("ERROR: Claude API key not configured", .logToServer)
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
        guard let claudeBodyData = convertToClaudeRequest(request: request, secrets: secrets) else {
            log("ERROR: Failed to convert request to Claude format", .logToServer)
            return nil
        }
        
        log("Claude request body created successfully", .logToServer)
        
        urlRequest.httpBody = claudeBodyData
        return urlRequest
    }
    
    
    /// Convert OpenAI-style request to Claude format
    static func convertToClaudeRequest<AIRequest>(request: AIRequest,
                                                          secrets: Secrets) -> Data? where AIRequest: StitchAIRequestable {
        
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
        let claudeModel = getClaudeModel(for: request, secrets: secrets)
        
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
        
        // Add streaming if present
        if let stream = payloadJSON["stream"] as? Bool, stream {
            claudeRequest["stream"] = true
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
    static func getClaudeModel<AIRequest>(for request: AIRequest,
                                                  secrets: Secrets) -> String where AIRequest: StitchAIRequestable {
        // First check if user has selected a specific Claude model from the UI
        let userSelectedModel = UserDefaults.standard.string(forKey: StitchAppSettings.CLAUDE_MODEL.rawValue)
        
        if let selectedModel = userSelectedModel, !selectedModel.isEmpty {
            log("Using user-selected Claude model: \(selectedModel)", .logToServer)
            return selectedModel
        }
        
        // Fallback to secrets configuration based on request type
        let requestTypeName = String(describing: type(of: request))
        let defaultModel = "claude-3-5-sonnet-20241022"
        
        if requestTypeName.contains("Graph") {
            return secrets.claudeModelGraphCreation ?? defaultModel
        } else if requestTypeName.contains("Js") || requestTypeName.contains("JS") {
            return secrets.claudeModelJsNode ?? defaultModel
        } else if requestTypeName.contains("Description") {
            return secrets.claudeModelGraphDescription ?? defaultModel
        } else {
            return secrets.claudeModelGraphCreation ?? defaultModel
        }
    }
    
    /// Make Claude API request
    func makeClaudeRequest<AIRequest>(for urlRequest: URLRequest,
                                              with request: AIRequest,
                                              attempt: Int,
                                              document: StitchDocumentViewModel) async -> Result<(OpenAIMessage, URLResponse), Error> where AIRequest: StitchAIRequestable {
        
        let result = await Result { @Sendable in
            try await fetchWithRetries(urlRequest)
        }
        
        switch result {
        case .success(let success):
            let jsonResponse = String(data: success.0, encoding: .utf8)
            log("Claude API Response Status: Success")
            log("Claude Response Body: \(jsonResponse ?? "none")")
            
            if let httpResponse = success.1 as? HTTPURLResponse {
                log("Claude Response HTTP Status: \(httpResponse.statusCode)")
                log("Claude Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            do {
                let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: success.0)
                log("ClaudeResponse: claudeResponse: \(claudeResponse)")
                let openAIResponse = claudeResponse.toOpenAIResponse()
                
                guard let firstChoice = openAIResponse.choices.first else {
                    log("ERROR: Claude response has no choices")
                    return .failure(StitchAIManagerError.firstChoiceNotDecoded)
                }
                
                log("Claude response successfully converted to OpenAI format")
                return .success((firstChoice.message, success.1))
            } catch {
                log("ERROR: Claude response decoding failed: \(error)")
                log("Raw response for debugging: \(jsonResponse ?? "none")")
                return .failure(StitchAIManagerError.responseDecodingFailure("\(error)"))
            }
            
        case .failure(let failure):
            log("Claude API Request Failed: \(failure)")
            
            if let httpError = failure as? URLError {
                log("Claude URLError details: code=\(httpError.code.rawValue), localizedDescription=\(httpError.localizedDescription)")
            }
            
            return .failure(failure)
        }
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
