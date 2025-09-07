//
//  AIRequestFunctions.swift
//  Stitch
//
//  Created by Claude Code on 9/5/25.
//

import Foundation
import SwiftUI

// MARK: - Pure Functions for AI Requests

/// Parameters needed for any AI request
struct AIRequestParams {
    let id: UUID
    let dataGlossaryPrompt: String
    let assistantPrompt: String
    let textInput: String
    let base64Image: String?
    let secrets: Secrets
}

/// Make a request to OpenAI's Responses endpoint with streaming
@MainActor
func makeOpenAIStreamingRequest(
    params: AIRequestParams,
    model: OpenAIModel,
    verbosity: OpenAIVerbosity,
    reasoningEffort: OpenAIReasoningEffort,
    document: StitchDocumentViewModel
) async throws -> String {
    
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
        fatalError("OpenAI Responses: Invalid URL")
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(params.secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Build request body using correct Responses API format
    var requestBody: [String: Any] = [
        "model": model.rawValue,
        "stream": true
    ]
    
    // Add reasoning parameters
    requestBody["reasoning"] = [
        "summary": "auto",
        "effort": reasoningEffort.rawValue
    ]
    
    let instructions = """
    \(params.dataGlossaryPrompt)
    
    \(params.assistantPrompt)
    """
    
    requestBody["instructions"] = instructions
    
    // Build input using correct Responses API format
    if let imageData = params.base64Image {
        // Multimodal request - use array format with role-based messages
        requestBody["input"] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": params.textInput
                    ],
                    [
                        "type": "input_image",
                        "image_url": "data:image/jpeg;base64,\(imageData)"
                    ]
                ]
            ]
        ]
    } else {
        // Text-only request - use simple string format
        requestBody["input"] = params.textInput
    }
    
    // Log request details for debugging
    if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) {
        print("🔍 Total request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
        
        // Log readable request structure (truncated)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            let truncatedRequest = jsonString.count > 2000 ? String(jsonString.prefix(2000)) + "...[TRUNCATED]" : jsonString
            print("📤 Outgoing OpenAI Request: \(truncatedRequest)")
        }
    }
    
    // Set initial streaming state
    document.isStreamingResponses = true
    document.streamingReasoningText = "Thinking..."
    
    // Accumulate response data
    var streamingResponse = ""
    var accumulatedReasoning = ""
    
    // Track token deltas for eager parsing
    var tokenDeltaCount = 0
    let eagerParsingThreshold = 60 // Parse every N delta events
    
    // Track timing for all streaming milestones
    let requestStartTime = Date()
    var firstReasoningTime: Date? = nil
    var firstCodeContentTime: Date? = nil
    var responseCompletedTime: Date? = nil
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("OpenAI Responses: No HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = try await URLSession.shared.data(for: request).0
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            log("OpenAI request failed with status: \(httpResponse.statusCode), error: \(errorString)", .logToServer)
            fatalError("OpenAI request failed with status \(httpResponse.statusCode)")
        }
        
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    break
                }
                
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    await handleOpenAIStreamingEvent(
                        json: json,
                        streamingResponse: &streamingResponse,
                        accumulatedReasoning: &accumulatedReasoning,
                        document: document,
                        requestStartTime: requestStartTime,
                        firstReasoningTime: &firstReasoningTime,
                        firstCodeContentTime: &firstCodeContentTime,
                        responseCompletedTime: &responseCompletedTime,
                        tokenDeltaCount: &tokenDeltaCount,
                        eagerParsingThreshold: eagerParsingThreshold,
                        originalCodeLength: params.textInput.count
                    )
                }
            }
        }
        
        // Reset streaming UI state
        await MainActor.run {
            document.isStreamingResponses = false
            document.streamingReasoningText = ""
        }
        
        // Print comprehensive timing summary
        let totalDuration = Date().timeIntervalSince(requestStartTime)
        print("⏱️ OpenAI Streaming Request Timing Summary:")
        print("   → Total request duration: \(String(format: "%.2f", totalDuration)) seconds")
        
        if let completionTime = responseCompletedTime {
            print("   → Response completed: \(String(format: "%.2f", completionTime.timeIntervalSince(requestStartTime))) seconds after start")
            
            // Calculate phase durations if we have all milestones
            if let firstReasoningTime = firstReasoningTime, let firstCodeTime = firstCodeContentTime {
                let reasoningPhase = firstCodeTime.timeIntervalSince(firstReasoningTime)
                let codePhase = completionTime.timeIntervalSince(firstCodeTime)
                print("   → Reasoning phase duration: \(String(format: "%.2f", reasoningPhase)) seconds (first code - first reasoning)")
                print("   → Code generation phase duration: \(String(format: "%.2f", codePhase)) seconds (completed - first code)")
            }
        } else {
            print("   → Response completed: Not received")
        }
        
        return streamingResponse
        
    } catch {
        await MainActor.run {
            document.isStreamingResponses = false
            document.streamingReasoningText = ""
        }
        throw error
    }
}

/// Make a request to Claude's Messages endpoint
@MainActor
func makeClaudeRequest(
    params: AIRequestParams,
    model: ClaudeModel,
    document: StitchDocumentViewModel
) async throws -> String {
    
    log("Making Claude request with model: \(model.rawValue)", .logToServer)
    
    guard let claudeAPIKey = params.secrets.claudeAPIKey, !claudeAPIKey.isEmpty else {
        log("ERROR: Claude API key not configured", .logToServer)
        throw StitchAIManagerError.secretsNotFound
    }
    
    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
        throw StitchAIStreamingError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    
    // Convert to Claude format
    let instructions = """
    \(params.dataGlossaryPrompt)
    
    \(params.assistantPrompt)
    """
    
    var claudeBody: [String: Any] = [
        "model": model.rawValue, // Use the actual model parameter
        "max_tokens": 4096,
        "system": instructions
    ]
    
    // Handle text + optional image input
    if let imageData = params.base64Image {
        claudeBody["messages"] = [[
            "role": "user",
            "content": [
                ["type": "text", "text": params.textInput],
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": imageData
                    ]
                ]
            ]
        ]]
    } else {
        claudeBody["messages"] = [[
            "role": "user",
            "content": params.textInput
        ]]
    }
    
    request.httpBody = try JSONSerialization.data(withJSONObject: claudeBody)
    
    // Log request details for debugging
    if let jsonData = request.httpBody {
        print("🔍 Total Claude request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
        print("📤 Using Claude model: \(model.rawValue)")
    }
    
    // Set streaming UI state
    document.isStreamingResponses = true
    document.streamingReasoningText = "Claude is thinking..."
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Reset streaming UI state
        document.isStreamingResponses = false
        document.streamingReasoningText = ""
        
        guard let httpResponse = response as? HTTPURLResponse else {
            log("Claude request: No HTTP response", .logToServer)
            // throw StitchAIManagerError.requestFailed
            fatalError()
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            log("Claude request failed with status code: \(httpResponse.statusCode)", .logToServer)
            log("Claude response headers: \(httpResponse.allHeaderFields)", .logToServer)
            
            // Log the error response body for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                log("Claude error response body: \(errorString)", .logToServer)
                print("🚨 Claude API Error (\(httpResponse.statusCode)): \(errorString)")
            } else {
                log("Claude error response body: (could not decode as UTF-8)", .logToServer)
            }
            
            throw StitchAIStreamingError.rateLimit // Assume rate limit for now
        }
        
        // Parse Claude response
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let content = claudeResponse.content.compactMap { $0.text }.joined()
        
        log("Claude request completed successfully", .logToServer)
        return content
        
    } catch {
        document.isStreamingResponses = false
        document.streamingReasoningText = ""
        
        log("Claude request failed: \(error)", .logToServer)
        throw error
    }
}

/// Provider-agnostic orchestrator function
@MainActor
func makeAIRequest(
    params: AIRequestParams,
    openAIModel: OpenAIModel,
    claudeModel: ClaudeModel,
    verbosity: OpenAIVerbosity,
    reasoningEffort: OpenAIReasoningEffort,
    document: StitchDocumentViewModel
) async throws -> String {
    
    let provider = AIProviderConfig.shared.currentProvider
    print("🔥 DEBUG: makeAIRequest using provider: \(provider.displayName)")
    log("makeAIRequest: Using provider: \(provider.displayName)", .logToServer)
    
    switch provider {
    case .openAI:
        return try await makeOpenAIStreamingRequest(
            params: params,
            model: openAIModel,
            verbosity: verbosity,
            reasoningEffort: reasoningEffort,
            document: document
        )
    case .claude:
        return try await makeClaudeRequest(
            params: params,
            model: claudeModel,
            document: document
        )
    }
}

// MARK: - Helper Functions

private func handleOpenAIStreamingEvent(
    json: [String: Any],
    streamingResponse: inout String,
    accumulatedReasoning: inout String,
    document: StitchDocumentViewModel,
    requestStartTime: Date,
    firstReasoningTime: inout Date?,
    firstCodeContentTime: inout Date?,
    responseCompletedTime: inout Date?,
    tokenDeltaCount: inout Int,
    eagerParsingThreshold: Int,
    originalCodeLength: Int
) async {
    // Handle different types of streaming events
    guard let eventType = json["type"] as? String else { return }
    
    switch eventType {
    case "response.output_text.delta":
        if let delta = json["delta"] as? String {
            // Record timing for first actual code content
            if firstCodeContentTime == nil && !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                firstCodeContentTime = Date()
                let timeToFirstCode = firstCodeContentTime!.timeIntervalSince(requestStartTime)
                print("🚀 First code content received after \(String(format: "%.2f", timeToFirstCode)) seconds: \"\(delta.prefix(50))\(delta.count > 50 ? "..." : "")\"")
            }
            streamingResponse += delta
            
            // Eager parsing: increment counter and attempt parsing at threshold
            tokenDeltaCount += 1
        }
    
    case "response.content_part.added":
        // This indicates a new content part is starting (might be code output)
        if let part = json["part"] as? [String: Any],
           let partType = part["type"] as? String {
            print("📝 Content part started: \(partType)")
            if partType == "output_text" && firstCodeContentTime == nil {
                // This is likely the start of actual code output
                print("🎯 Output text part detected - code content should start soon")
            }
        }
    
    case "response.reasoning_summary_text.delta":
        if let delta = json["delta"] as? String {
            // Record timing for first reasoning text
            if firstReasoningTime == nil && !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                firstReasoningTime = Date()
                let timeToFirstReasoning = firstReasoningTime!.timeIntervalSince(requestStartTime)
                print("🧠 First reasoning received after \(String(format: "%.2f", timeToFirstReasoning)) seconds: \"\(delta.prefix(50))\(delta.count > 50 ? "..." : "")\"")
            }
            
            accumulatedReasoning += delta
            
            // Extract header like StreamingDemoView does
            await MainActor.run {
                let boldPattern = #"\*\*(.*?)\*\*"#
                let regex = try? NSRegularExpression(pattern: boldPattern, options: [])
                let range = NSRange(location: 0, length: accumulatedReasoning.utf16.count)
                
                if let matches = regex?.matches(in: accumulatedReasoning, options: [], range: range),
                   let firstMatch = matches.first,
                   let headerRange = Range(firstMatch.range(at: 1), in: accumulatedReasoning) {
                    let headerText = String(accumulatedReasoning[headerRange])
                    
                    withAnimation {
                        document.streamingReasoningText = headerText
                    }
                } else {
                    // Fallback to showing full accumulated reasoning if no header found
                    document.streamingReasoningText = accumulatedReasoning
                }
            }
        }
    
    case "response.completed":
        // Record completion timing
        responseCompletedTime = Date()
        let totalTime = responseCompletedTime!.timeIntervalSince(requestStartTime)
        print("✅ Response completed after \(String(format: "%.2f", totalTime)) seconds")
        
        await MainActor.run {
            document.isStreamingResponses = false
        }
    
    case "error":
        if let error = json["error"] as? [String: Any] {
            fatalErrorIfDebug("OpenAI Responses API Error: \(error)")
        }
    
    // Handle legacy event types for backward compatibility
    case "response.output_content.delta":
        if let delta = json["delta"] as? String {
            if firstCodeContentTime == nil && !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                firstCodeContentTime = Date()
                let timeToFirstCode = Date().timeIntervalSince(requestStartTime)
                print("💻 First code content received: \(String(format: "%.2f", timeToFirstCode)) seconds")
            }
            
            streamingResponse += delta
            tokenDeltaCount += 1
        }
    
    default:
        // Log unhandled reasoning events for debugging
        if eventType.contains("reasoning") {
            print("🧠 Unhandled reasoning event: \(eventType)")
        } else if eventType.contains("output") || eventType.contains("content") {
            print("📄 Unhandled content event: \(eventType)")
        } else {
            print("❓ Unhandled event type: \(eventType)")
        }
    }
}
