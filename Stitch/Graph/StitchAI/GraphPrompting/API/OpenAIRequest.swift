//
//  OpenAIRequest.swift
//  Core implementation for making requests to OpenAI's API with retry logic and error handling.
//  This file handles API communication, response parsing, and state management for the Stitch app.
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation
@preconcurrency import SwiftyJSON
import SwiftUI
import Sentry
import SwiftyJSON

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

/// Configuration for AI provider selection
final class AIProviderConfig: @unchecked Sendable {
    static let shared = AIProviderConfig()
    
    private let userDefaults = UserDefaults.standard
    private let providerKey = "ai_provider_preference"
    
    var currentProvider: AIProvider {
        get {
            guard let rawValue = userDefaults.string(forKey: providerKey),
                  let provider = AIProvider(rawValue: rawValue) else {
                return .openAI // Default to OpenAI
            }
            return provider
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: providerKey)
        }
    }
    
    private init() {}
}

extension StitchAIManager {
    
    // Used when we need to kick off a request, either initially or as a retry
    @MainActor
    func getAITask(request: AIGraphCreationRequest,
                   attempt: Int,
                   document: StitchDocumentViewModel,
                   canShareAIRetries: Bool) -> Task<OpenAIMessage, any Error> {
        Task(priority: .high) { [weak self] in
            guard let aiManager = self else {
                fatalErrorIfDebug()
                throw NSError()
            }
            
            switch await aiManager.startAIRequest(
                request,
                attempt: attempt,
                lastCapturedError: document.llmRecording.actionsError ?? "",
                document: document) {
                
            case .success(let result):
                log("getOpenAIStreamingTask: succeeded")
                
                // Handle successful response
                // Note: does not fire until we properly handle the whole request
                await MainActor.run { [weak document] in
                    guard let document = document else {
                        fatalErrorIfDebug("getOpenAIStreamingTask: no document")
                        return
                    }
                    aiManager.aiGraphRequestCompleted(request: request,
                                                      document: document)
                }
                
                return result
                
            case .failure(let error):
                log("getOpenAIStreamingTask: error: \(error.description)")
                
                // If the error was a timeout or rate limit, we'll want to try again:
                if error.shouldRetryRequest {
                    await aiManager.retryOrShowErrorModal(
                        request: request,
                        steps: Array(document.llmRecording.streamedSteps),
                        attempt: attempt,
                        document: document,
                        canShareAIRetries: canShareAIRetries)
                }
                
                // Else, if e.g. 'no internet connection', we won't try again and will show error modal to the user.
                else {
                    // TODO: do we really need to do this on `MainActor.run`? See also note in `retryOrShowErrorModal`
                    await MainActor.run { [weak document] in
                        guard let document = document else {
                            fatalErrorIfDebug("getOpenAIStreamingTask: no document")
                            document?.aiManager?.cancelCurrentRequest()
                            return
                        }
                        document.handleNonRetryableError(error, request)
                    }
                }
                
                throw error
            }
        }
    }
        
    // Note: the failures that can happen in here are catastrophic and meant for us as developers, not something the user can take action on
    static func getURLRequestForOpenAI<AIRequest>(request: AIRequest,
                                                  secrets: Secrets) -> URLRequest? where AIRequest: StitchAIRequestable {
        
        let config = request.config
                
        // Configure request headers and parameters
        var urlRequest = URLRequest(url: OPEN_AI_BASE_URL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        let bodyPayload = try? request.getPayloadData()
        urlRequest.httpBody = bodyPayload
        
        return urlRequest
    }
    
    /// Execute the AI API request with retry logic
    // Routes to either OpenAI or Claude based on configuration
    func startAIRequest<AIRequest>(_ request: AIRequest,
                                   attempt: Int,
                                   lastCapturedError: String,
                                   document: StitchDocumentViewModel) async -> Result<OpenAIMessage, StitchAIStreamingError> where AIRequest: StitchAIRequestable {
        
        print("🔥 DEBUG: startAIRequest called!")
        log("StitchAIManager: startAIRequest called", .logToServer)
        
        let provider = AIProviderConfig.shared.currentProvider
        print("🔥 DEBUG: Current provider: \(provider.displayName)")
        log("StitchAIManager: startAIRequest: Using provider: \(provider.displayName)", .logToServer)
        
        switch provider {
        case .openAI:
            log("StitchAIManager: Routing to OpenAI", .logToServer)
            return await startOpenAIRequest(request,
                                            attempt: attempt,
                                            lastCapturedError: lastCapturedError,
                                            document: document)
        case .claude:
            log("StitchAIManager: Routing to Claude", .logToServer)
            return await startClaudeRequest(request,
                                            attempt: attempt,
                                            lastCapturedError: lastCapturedError,
                                            document: document)
        }
    }
    
    /// Execute the OpenAI API request with retry logic
    // fka `makeRequest`
    func startOpenAIRequest<AIRequest>(_ request: AIRequest,
                                       attempt: Int,
                                       lastCapturedError: String,
                                       document: StitchDocumentViewModel) async -> Result<OpenAIMessage, StitchAIStreamingError> where AIRequest: StitchAIRequestable {
        
        // Check if we've exceeded retry attempts
        guard attempt <= request.config.maxRetries else {
            log("All StitchAI retry attempts exhausted", .logToServer)
            return .failure(.maxRetriesError(request.config.maxRetries,
                                             lastCapturedError))
        }
        
        guard let urlRequest = Self.getURLRequestForOpenAI(request: request,
                                                           secrets: self.secrets) else {
            log("StitchAIManager: startOpenAIRequest: could not get request", .logToServer)
            return .failure(.urlRequestCreationFailure)
        }
        
        let streamOpeningResult = await self.makeRequest(
            for: urlRequest,
            with: request,
            attempt: attempt,
            document: document)
        
        switch streamOpeningResult {
            
        case .success(let response):
            // Even if we had a successful response, may have hit a rate limit?
            // TODO: is this still necessary for streaming requests?
            if let error = handlePossibleRateLimit(
                response: response.1,
                request: request) {
                return .failure(error)
            }
            
            return .success(response.0)
            
        case .failure(let error):
            // Note: `error` might be a cancellation, which is acceptable and not an error
            log("StitchAIManager: startOpenAIRequest: streaming error: \(error.localizedDescription)", .logToServer)
            if let error = handleOpenAIStreamingError(
                error,
                attempt: attempt,
                request: request) {
                return .failure(error)
            }
            
            return .failure(.other(error))
        }
    }
     
    private func handlePossibleRateLimit<AIRequest>(response: URLResponse,
                                                    request: AIRequest) -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            // Retry on rate limit or server errors
            if httpResponse.statusCode == 429 || // Rate limit
                httpResponse.statusCode >= 500 {  // Server error
                log("StitchAI Request failed with status code: \(httpResponse.statusCode)", .logToServer)
                log("Retrying in \(request.config.retryDelay) seconds")
                
                return .rateLimit
            }
        }
        
        // else no error, we're all good!
        return nil
    }
    
    // An error that occurred when we attempted to open the stream, or as the stream was open
    // Note: NOT the same as an error when validating or applying parsed Steps; for that, see `handleErrorWhenApplyingChunk`
    private func handleOpenAIStreamingError<AIRequest>(_ error: Error,
                                                       attempt: Int,
                                                       request: AIRequest) -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        log("OpenAI request failed: \(error)")
        
        if let _ = (error as? CancellationError) {
            return nil // Cancellation is not an error
        }
        
        guard let error = error as NSError? else {
            // If we don't have an NSError, treat error as invalid url ?
            return .invalidURL
        }
        
        // Handle network errors
        
        // Don't show error for cancelled requests
        if error.code == NSURLErrorCancelled {
            // return .requestCancelled
            return nil // Cancellation is not an error
        }
        
        // Handle timeout errors
        else if error.code == NSURLErrorTimedOut {
            log("Timeout error count: \(attempt)")
            
            if attempt > request.config.maxTimeoutErrors {
                return .maxTimeouts //.multipleTimeoutErrors(request, error.localizedDescription)
            } else {
                return .timeout //.timeout(request, error.localizedDescription)
            }
        }
        
        // Handle network connection errors
       else if error.code == NSURLErrorNotConnectedToInternet ||
            error.code == NSURLErrorNetworkConnectionLost {
            return .internetConnectionFailed
        }
        
        // Handle other errors
        else {
            return .other(error)
        }
    }
    

    // Note: this actually fires WHENEVER the stream is closed, e.g. even when task is cancelled
    
    // We successfully opened the stream and received bits until the stream was closed (without an error?).
    // fka `openAIRequestCompleted`
    @MainActor
    func aiGraphRequestCompleted(request: AIGraphCreationRequest,
                                 document: StitchDocumentViewModel) {
        log("openAIStreamingCompleted called")
        
        document.reduxFocusedField = nil
        
        // Set auto-hiding flag before hiding menu
        document.insertNodeMenuState.isAutoHiding = true
        
        document.insertNodeMenuState.show = false
        document.aiManager?.cancelCurrentRequest()
        
        // Clear any dropped image from the insert menu
        document.insertNodeMenuState.droppedImage = nil
        document.insertNodeMenuState.droppedImageBase64 = nil
        
        log("Storing user prompt and request id")
        document.llmRecording.promptForTrainingDataOrCompletedRequest = request.userPrompt
        document.llmRecording.requestIdFromCompletedRequest = request.id
        
        // Only ask for rating if we received some actions
        if !document.llmRecording.streamedSteps.isEmpty {
            document.llmRecording.modal = .ratingToast(userInputPrompt: request.userPrompt)
        }
                
        document.encodeProjectInBackground()
    }
    
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
    private static func convertToClaudeRequest<AIRequest>(request: AIRequest,
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
            log("Final Claude request body:\n\(debugString)", .logToServer)
        }
        
        return try? JSONSerialization.data(withJSONObject: claudeRequest)
    }
    
    /// Extract media type from data URL (e.g., "data:image/jpeg;base64,..." -> "image/jpeg")
    private static func extractMediaTypeFromDataURL(_ dataURL: String) -> String? {
        if let range = dataURL.range(of: "data:") {
            let afterData = String(dataURL[range.upperBound...])
            if let semicolonRange = afterData.range(of: ";") {
                return String(afterData[..<semicolonRange.lowerBound])
            }
        }
        return nil
    }
    
    /// Get the appropriate Claude model based on request type
    private static func getClaudeModel<AIRequest>(for request: AIRequest,
                                                  secrets: Secrets) -> String where AIRequest: StitchAIRequestable {
        // This is a simplified approach - you might want to add proper type checking
        let requestTypeName = String(describing: type(of: request))
        
        // Default Claude model to use if specific ones aren't configured
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
    private func makeClaudeRequest<AIRequest>(for urlRequest: URLRequest,
                                              with request: AIRequest,
                                              attempt: Int,
                                              document: StitchDocumentViewModel) async -> Result<(OpenAIMessage, URLResponse), Error> where AIRequest: StitchAIRequestable {
        
        let result = await Result { @Sendable in
            try await fetchWithRetries(urlRequest)
        }
        
        switch result {
        case .success(let success):
            let jsonResponse = String(data: success.0, encoding: .utf8)
            log("Claude API Response Status: Success", .logToServer)
            log("Claude Response Body: \(jsonResponse ?? "none")", .logToServer)
            
            if let httpResponse = success.1 as? HTTPURLResponse {
                log("Claude Response HTTP Status: \(httpResponse.statusCode)", .logToServer)
                log("Claude Response Headers: \(httpResponse.allHeaderFields)", .logToServer)
            }
            
            do {
                let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: success.0)
                let openAIResponse = claudeResponse.toOpenAIResponse()
                
                guard let firstChoice = openAIResponse.choices.first else {
                    log("ERROR: Claude response has no choices", .logToServer)
                    return .failure(StitchAIManagerError.firstChoiceNotDecoded)
                }
                
                log("Claude response successfully converted to OpenAI format", .logToServer)
                return .success((firstChoice.message, success.1))
            } catch {
                log("ERROR: Claude response decoding failed: \(error)", .logToServer)
                log("Raw response for debugging: \(jsonResponse ?? "none")", .logToServer)
                return .failure(StitchAIManagerError.responseDecodingFailure("\(error)"))
            }
            
        case .failure(let failure):
            log("Claude API Request Failed: \(failure)", .logToServer)
            
            if let httpError = failure as? URLError {
                log("Claude URLError details: code=\(httpError.code.rawValue), localizedDescription=\(httpError.localizedDescription)", .logToServer)
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

extension StitchAIRequestable {
    func request(document: StitchDocumentViewModel,
                 aiManager: StitchAIManager) async throws -> Self.FinalDecodedResult {
        print("🔥 DEBUG: StitchAIRequestable.request called for \(String(describing: type(of: self)))")
        log("StitchAIRequestable.request called for \(String(describing: type(of: self)))", .logToServer)
        
        let result = await aiManager.startAIRequest(self,
                                                    attempt: 0,
                                                    lastCapturedError: "",
                                                    document: document)
        
        switch result {
            
        case .success(let msg):
            log("StitchAIRequestable: requestForMessage: success")
            let initialDecodedResult = try Self.parseOpenAIResponse(message: msg)
            let result = try Self.validateResponse(decodedResult: initialDecodedResult)
            return result

        case .failure(let failure):
            log("StitchAIRequestable: requestForMessage: failure")
            logToServerIfRelease("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
            throw failure
        }
    }
}

extension StitchAIFunctionRequestable {
    /// Called when an OpenAI function expects subsequent functions to call.
//    func requestMessagesForNextFn<ResultType>(returnedFnType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
//                                              requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
//                                              document: StitchDocumentViewModel,
//                                              aiManager: StitchAIManager) async throws -> [OpenAIMessage] where ResultType: Codable {
//        let result = await aiManager.startOpenAIRequest(self,
//                                                        attempt: 0,
//                                                        lastCapturedError: "",
//                                                        document: document)
//        switch result {
//            
//        case .success(var msg):
//            log("StitchAIRequestable: requestForMessage: success")
//            let supplementarySystemPrompt = OpenAIMessage(
//                role: .system,
//                content: try returnedFnType.getAssistantPrompt(for: requestType)
//            )
//            
//            // Create tool message for function response
//            let responseToolMsg = try msg.createNewToolMessage()
//            
//            return [supplementarySystemPrompt, msg, responseToolMsg]
//        case .failure(let failure):
//            log("StitchAIRequestable: requestForMessage: failure")
//            logToServerIfRelease("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
//            throw failure
//        }
//    }
    
    /// Called when last AI function is called.
    func requestMessageForFn(document: StitchDocumentViewModel,
                             aiManager: StitchAIManager) async throws -> OpenAIMessage {
        let result = await aiManager.startAIRequest(self,
                                                    attempt: 0,
                                                    lastCapturedError: "",
                                                    document: document)
        switch result {
            
        case .success(let msg):
            log("StitchAIRequestable: requestForMessage: success")
            return msg
        case .failure(let failure):
            log("StitchAIRequestable: requestForMessage: failure")
            logToServerIfRelease("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
            throw failure
        }
    }
}