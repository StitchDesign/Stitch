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
    
    // Use static content for consistent behavior (avoids UUID and non-deterministic issues)
    let instructions = try loadStitchStaticPrompt()
    
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
            log("OpenAI request failed with status: \(httpResponse.statusCode), error: \(errorString)")
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
func makeClaudeStreamingRequest(
    params: AIRequestParams,
    model: ClaudeModel,
    document: StitchDocumentViewModel
) async throws -> String {
    
    log("=== makeClaudeRequest STARTED ===")
    
    log("Making Claude request with model: \(model.rawValue)")
    
    guard let claudeAPIKey = StitchStore.claudeAPIKey, !claudeAPIKey.isEmpty else {
        log("ERROR: Claude API key not configured in settings")
        throw StitchAIManagerError.claudeAPIKeyNotSet
    }
    
    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
        throw StitchAIStreamingError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("output-128k-2025-02-19,prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
    
    // Use static content for consistent caching (avoids UUID and non-deterministic issues)
    let stitchStaticContent = try loadStitchStaticPrompt()
    
    let fullSystemPrompt: [String: Any] = [
        "type": "text", 
        "text": stitchStaticContent, // Use static content for consistent caching
        "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache control on large Stitch static content
    ]
    
    var claudeBody: [String: Any] = [
        "model": model.rawValue, // Use the actual model parameter
        "max_tokens": 32768, // High limit for complex code generation (with beta header support)
        "system": [fullSystemPrompt],
        "stream": true // Enable streaming for better UX
    ]
    
    // Add extended thinking for supported models
    let supportsThinking = model.rawValue.contains("sonnet-4") || 
                         model.rawValue.contains("opus-4") || 
                         model.rawValue.contains("sonnet-3.7") ||
                         model.rawValue.contains("claude-4") ||
                         model.rawValue.contains("claude-3.7")
    
    if supportsThinking {
        claudeBody["thinking"] = [
            "type": "enabled",
            "budget_tokens": 10000  // Allow up to 10k tokens for thinking
        ]
        log("Extended thinking enabled for model: \(model.rawValue) with 10k token budget")
    } else {
        log("Extended thinking not supported for model: \(model.rawValue)")
    }
    
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
    
    // Log request details for debugging including cache structure
    if let jsonData = request.httpBody {
        print("🔍 Total Claude request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
        print("📤 Using Claude model: \(model.rawValue)")
        
        // Log stitch static content stats for cache debugging
        let stitchTokenEstimate = stitchStaticContent.count / 3 // Rough token estimate
        print("📚 Stitch static system prompt stats:")
        print("   → Characters: \(stitchStaticContent.count)")
        print("   → Estimated tokens: ~\(stitchTokenEstimate)")
        print("   → Cache eligible: \(stitchTokenEstimate > 1024 ? "✅ YES" : "❌ NO") (>1024 tokens required)")
    }
    
    // Set streaming UI state
    document.isStreamingResponses = true
    document.streamingReasoningText = "Claude is thinking..."
    
    // Track request timing
    let requestStartTime = Date()
    
    do {
        log("=== Starting Claude streaming request ===")
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            log("Claude request: No HTTP response")
            throw StitchAIStreamingError.other(URLError(.badServerResponse))
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            log("Claude streaming request failed with status: \(httpResponse.statusCode)")
            throw StitchAIStreamingError.other(URLError(.badServerResponse))
        }
        
        log("Claude streaming response status: \(httpResponse.statusCode)")
        
        var accumulatedContent = ""
        var accumulatedThinking = ""
        var totalUsage: ClaudeUsage?
        
        var firstThinkingTime: Date?
        var firstContentTime: Date?
        
        // Debug: Track all thinking steps for debugging
        var allThinkingSteps: [String] = []
        
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
            log("🔄 Claude streaming event: \(eventType ?? "unknown") - JSON keys: \(json.keys.joined(separator: ", "))")
            
            switch eventType {
            case "message_start":
                log("Claude stream started")
                
            case "content_block_start":
                if let contentBlock = json["content_block"] as? [String: Any],
                   let type = contentBlock["type"] as? String {
                    if type == "thinking" {
                        log("🧠 Claude thinking block started")
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
                    log("Delta received: \(delta)")
                    if let thinkingText = delta["thinking"] as? String {
                        // This is thinking content
                        // log("🧠 Thinking delta received: '\(thinkingText)' (length: \(thinkingText.count))")
                        accumulatedThinking += thinkingText
                        allThinkingSteps.append(thinkingText)
                        
                        // Update UI with thinking progress (just show raw content, no prefix)
                        await MainActor.run {
                            document.streamingReasoningText = accumulatedThinking
                            // log("📱 UI updated with thinking text, total length: \(accumulatedThinking.count)")
                        }
                    } else if let text = delta["text"] as? String {
                        // This is regular text content
                        // log("📝 Text delta received: '\(text)' (length: \(text.count))")
                        accumulatedContent += text
                        
                        // Clear thinking text once content starts
                        await MainActor.run {
                            if !document.streamingReasoningText.isEmpty {
                                document.streamingReasoningText = ""
                                // log("📱 Cleared thinking text - switching to content")
                            }
                        }
                    } else {
                        log("⚠️  Delta received but no 'thinking' or 'text' field found")
                    }
                } else {
                    log("⚠️  content_block_delta event with no delta field")
                }
                
            case "message_delta":
                if let usage = json["usage"] as? [String: Any] {
                    totalUsage = try? JSONDecoder().decode(ClaudeUsage.self, from: JSONSerialization.data(withJSONObject: usage))
                }
                
            case "message_stop":
                // log("Claude stream completed")
                let totalTime = Date().timeIntervalSince(requestStartTime) * 1000
                // log("⚡ Total stream time: \(String(format: "%.0f", totalTime))ms")
                
                // Monitor cache performance
                if let usage = totalUsage {
                    await monitorClaudeStreamingCachePerformance(usage: usage)
                }
                
            default:
                continue
            }
        }
        
        // Reset streaming UI state
        await MainActor.run {
            document.isStreamingResponses = false
            document.streamingReasoningText = ""
        }
        
        log("Claude streaming completed successfully")
        log("Final content length: \(accumulatedContent.count) characters")
        log("Total thinking length: \(accumulatedThinking.count) characters")
        log("📝 Thinking steps received: \(allThinkingSteps.count)")
        
        // Debug: Print all thinking steps for debugging
        if !allThinkingSteps.isEmpty {
            log("🧠 All thinking deltas received:")
            for (index, step) in allThinkingSteps.enumerated() {
                log("   Step \(index + 1): '\(step)'")
            }
        }
        
        return accumulatedContent
        
    } catch {
        await MainActor.run {
            document.isStreamingResponses = false
            document.streamingReasoningText = ""
        }
        
        // Log failure timing
        let failureDuration = Date().timeIntervalSince(requestStartTime)
        print("❌ Claude request failed after \(String(format: "%.2f", failureDuration)) seconds")
        
        log("Claude request failed: \(error)")
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
    log("makeAIRequest: Using provider: \(provider.displayName)")
    
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
        return try await makeClaudeStreamingRequest(
            params: params,
            model: claudeModel,
            document: document
        )
    }
}

// MARK: - Helper Functions

/// Load the stitch_static_prompt.txt content from app bundle for cache testing
private func loadStitchStaticPrompt() throws -> String {
    guard let path = Bundle.main.path(forResource: "stitch_static_prompt", ofType: "txt"),
          let content = try? String(contentsOfFile: path) else {
        throw StitchAIManagerError.systemPromptNotFound
    }
    return content
}

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


/// Monitor Claude prompt cache performance from streaming usage data in AIRequestFunctions
func monitorClaudeStreamingCachePerformance(usage: ClaudeUsage) async {
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

