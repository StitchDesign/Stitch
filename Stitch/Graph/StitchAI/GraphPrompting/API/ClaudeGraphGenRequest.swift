//
//  ClaudeStreamingRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/9/25.
//

import SwiftUI

/// Make a request to Claude's Messages endpoint
@MainActor
func makeClaudeStreamingRequest(
    previewWindowPrompt: String,
    userPrompt: String,
    base64Image: String?,
    model: ClaudeModel,
    document: StitchDocumentViewModel
) async throws -> String {
    
    log("=== makeClaudeStreamingRequest STARTED ===")
    
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
    
    // Static content component (data glossary + fixed instructions)
    let staticSystemPrompt: [String: Any] = [
        "type": "text",
        "text": stitchStaticContent, // Use static content for consistent caching
        "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache control on large Stitch static content
    ]
    
    // Preview window constraints component (cacheable per session)
    let previewWindowSystemPrompt: [String: Any] = [
        "type": "text",
        "text": previewWindowPrompt, // Contains preview window constraints
        "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache preview window info for session
    ]
    
    var claudeBody: [String: Any] = [
        "model": model.rawValue, // Use the actual model parameter
        "max_tokens": model.maxTokens, // Model-specific maximum output tokens
        "system": [staticSystemPrompt, previewWindowSystemPrompt], // Multi-component cached system prompt
        "stream": true // Enable streaming for better UX
    ]
    
    // Add extended thinking for supported models
    let supportsThinking = model.supportsThinking
    
    if supportsThinking {
        claudeBody["thinking"] = [
            "type": "enabled",
            "budget_tokens": 3000  // Reduced budget for more concise thinking
        ]
        log("Extended thinking enabled for model: \(model.rawValue) with 3k token budget for terse reasoning")
    } else {
        log("Extended thinking not supported for model: \(model.rawValue)")
    }
    
    // Handle text + optional image input
    if let imageData = base64Image {
        claudeBody["messages"] = [[
            "role": "user",
            "content": [
                ["type": "text", "text": userPrompt],
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": imageData
                    ],
                    "cache_control": ["type": "ephemeral", "ttl": "1h"] // Cache the image data for reuse
                ]
            ]
        ]]
    } else {
        claudeBody["messages"] = [[
            "role": "user",
            "content": userPrompt
        ]]
    }
    
    request.httpBody = try JSONSerialization.data(withJSONObject: claudeBody)
    
    // Log request details for debugging including cache structure
    if let jsonData = request.httpBody {
        log("🔍 Total Claude request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
        log("📤 Using Claude model: \(model.rawValue)")
        
#if DEV_DEBUG
        // Log stitch static content stats for cache debugging
        let stitchTokenEstimate = stitchStaticContent.count / 3 // Rough token estimate
        log("📚 Stitch static system prompt stats:")
        log("   → Characters: \(stitchStaticContent.count)")
        log("   → Estimated tokens: ~\(stitchTokenEstimate)")
        log("   → Cache eligible: \(stitchTokenEstimate > 1024 ? "✅ YES" : "❌ NO") (>1024 tokens required)")
        
        // Log request structure for debugging (without sensitive content)
        log("🔍 Claude request structure:")
        log("   → Model: \(model.rawValue)")
        log("   → Max tokens: \(model.maxTokens) (model-specific limit)")
        log("   → Stream: \(claudeBody["stream"] ?? false)")
        log("   → Has thinking: \(claudeBody["thinking"] != nil)")
        if let systemArray = claudeBody["system"] as? [[String: Any]] {
            log("   → System components: \(systemArray.count)")
            for (index, component) in systemArray.enumerated() {
                if let text = component["text"] as? String {
                    let charCount = text.count
                    let hasCache = component["cache_control"] != nil
                    log("     Component \(index + 1): \(charCount) chars, cached: \(hasCache)")
                }
            }
        }
        if let messages = claudeBody["messages"] as? [[String: Any]] {
            log("   → Messages: \(messages.count)")
            for (index, message) in messages.enumerated() {
                if let role = message["role"] as? String {
                    let contentType = message["content"] is String ? "text" : "multipart"
                    log("     Message \(index + 1): \(role) (\(contentType))")
                }
            }
        }
#endif
    }
    
    // Set streaming UI state
    document.isStreamingResponses = true
    document.streamingReasoningText = AI_THINKING_TEXT
    
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
            
            // Read error response body for detailed error information
            do {
                let errorData = try await URLSession.shared.data(for: request).0
                let errorMessage = await parseClaudeErrorResponse(errorData, statusCode: httpResponse.statusCode)
                log("Claude API Error Details: \(errorMessage)")
                throw StitchAIStreamingError.apiError(httpResponse.statusCode, errorMessage)
            } catch let apiError as StitchAIStreamingError {
                // Re-throw our custom error
                throw apiError
            } catch {
                // Fallback if we can't read the error response
                log("Failed to read Claude error response: \(error)")
                throw StitchAIStreamingError.apiError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode) - Unable to read error details")
            }
        }
        
        log("Claude streaming response status: \(httpResponse.statusCode)")
        
        var accumulatedContent = ""
        var accumulatedThinking = ""
        var totalUsage: ClaudeUsage?
        
        var firstThinkingTime: Date?
        var firstContentTime: Date?
        var lineCount = 0
        var eventCount = 0
        
        // Debug: Track all thinking steps for debugging
        var allThinkingSteps: [String] = []
        
        log("🔄 Starting to process Claude streaming response...")
        
        for try await line in asyncBytes.lines {
            lineCount += 1
            
            // Skip empty lines
            guard !line.isEmpty else {
                // log("📝 Skipping empty line \(lineCount)")
                continue
            }
            
            // log("📝 Received line \(lineCount): \(line.prefix(100))\(line.count > 100 ? "..." : "")")
            
            // Parse SSE format: "data: {json}"
            let jsonString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
            
            //            log("🔍 Processing JSON string: \(jsonString.prefix(200))\(jsonString.count > 200 ? "..." : "")")
            
            // Handle stream completion
            if jsonString == "[DONE]" {
                //                log("✅ Stream completion marker received")
                break
            }
            
            // Parse JSON event
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                //                log("⚠️ Failed to parse JSON from line: \(line)")
                continue
            }
            
            eventCount += 1
            let eventType = json["type"] as? String
            //            log("🎯 Event \(eventCount): \(eventType ?? "unknown") - JSON keys: \(json.keys.joined(separator: ", "))")
            
            switch eventType {
            case "message_start":
                log("Claude stream started")
                
            case "content_block_start":
                if let contentBlock = json["content_block"] as? [String: Any],
                   let type = contentBlock["type"] as? String {
                    if type == "thinking" {
                        //                        log("🧠 Claude thinking block started")
                        if firstThinkingTime == nil {
                            firstThinkingTime = Date()
                            // let thinkingLatency = Date().timeIntervalSince(requestStartTime) * 1000
                            //                            log("⚡ Time to first thinking: \(String(format: "%.0f", thinkingLatency))ms")
                        }
                    } else if type == "text" {
                        //                        log("📝 Claude text content block started")
                        if firstContentTime == nil {
                            firstContentTime = Date()
                            // let contentLatency = Date().timeIntervalSince(requestStartTime) * 1000
                            //                            log("⚡ Time to first content: \(String(format: "%.0f", contentLatency))ms")
                        }
                    }
                }
                
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any] {
                    //                    log("Delta received: \(delta)")
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
                        print("accumulated text: \n\(accumulatedContent)")
                        
                        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(accumulatedContent)
                        
                        // Syntax → Actions
                        let stitchActionsResult = try codeParserResult.deriveStitchActionsSync(
                            bindingDeclarations: codeParserResult.bindingDeclarations,
                            isStreaming: true)
                        
                        Task(priority: .high) { @MainActor [weak document] in
                            guard let document else { return }
                            stitchActionsResult.processAIGraph(document: document,
                                                               isStreaming: true)
                            print("streamed graph:\n\(document.graph.createSchema())")
                        }
                        
                        //                        // Clear thinking text once content starts
                        //                        await MainActor.run {
                        //                            if !document.streamingReasoningText.isEmpty {
                        //                                document.streamingReasoningText = ""
                        //                                // log("📱 Cleared thinking text - switching to content")
                        //                            }
                        //                        }
                    } else {
                        //                        log("⚠️  Delta received but no 'thinking' or 'text' field found")
                    }
                } else {
                    //                    log("⚠️  content_block_delta event with no delta field")
                }
                
            case "message_delta":
                if let usage = json["usage"] as? [String: Any] {
                    totalUsage = try? JSONDecoder().decode(ClaudeUsage.self, from: JSONSerialization.data(withJSONObject: usage))
                }
                
            case "message_stop":
                log("🏁 Claude stream completed - message_stop received")
                
                // Monitor cache performance
                if let usage = totalUsage {
                    await monitorClaudeStreamingCachePerformance(usage: usage)
                }
                
            default:
                log("❓ Unknown event type: \(eventType ?? "nil")")
                continue
            }
        }
        
        log("🔚 Finished processing Claude stream - Total lines: \(lineCount), Events: \(eventCount)")
        
        // Reset streaming UI state
        document.resetStreamingUIState()
        
        log("Claude streaming completed successfully")
        log("Final content length: \(accumulatedContent.count) characters")
        log("Total thinking length: \(accumulatedThinking.count) characters")
        log("📝 Thinking steps received: \(allThinkingSteps.count)")
        
        if accumulatedContent.isEmpty && accumulatedThinking.isEmpty {
            log("⚠️ WARNING: No content or thinking received from Claude!")
            log("🔍 Stream summary: \(lineCount) lines processed, \(eventCount) events handled")
        }
        
#if DEV_DEBUG
        // Debug: log all thinking steps as formatted text block
        if !allThinkingSteps.isEmpty {
            log("🧠 All thinking deltas received as text block:")
            let formattedThinking = allThinkingSteps.joined(separator: " ")
            log("\(formattedThinking)")
        }
#endif
        
        return accumulatedContent
        
    } catch {
        document.resetStreamingUIState()
        
        // Log failure timing
        let failureDuration = Date().timeIntervalSince(requestStartTime)
        log("❌ Claude request failed after \(String(format: "%.2f", failureDuration)) seconds")
        
        log("Claude request failed: \(error)")
        throw error
    }
}

/// Parse Claude API error response to extract detailed error information
@MainActor
func parseClaudeErrorResponse(_ errorData: Data, statusCode: Int) async -> String {
    do {
        // Try to parse as JSON
        if let json = try JSONSerialization.jsonObject(with: errorData) as? [String: Any] {
            // Claude API error format: { "type": "error", "error": { "type": "...", "message": "..." } }
            if let error = json["error"] as? [String: Any] {
                let errorType = error["type"] as? String ?? "unknown"
                let errorMessage = error["message"] as? String ?? "No message provided"
                return "\(errorType): \(errorMessage)"
            }
            
            // Fallback: look for direct message field
            if let message = json["message"] as? String {
                return message
            }
            
            // If we can parse JSON but no recognized structure, return the raw JSON
            if let jsonString = String(data: errorData, encoding: .utf8) {
                return "Raw error response: \(jsonString)"
            }
        }
    } catch {
        // JSON parsing failed
        log("Failed to parse Claude error JSON: \(error)")
    }
    
    // Last resort: return raw string
    if let rawString = String(data: errorData, encoding: .utf8) {
        return "Raw error response: \(rawString)"
    }
    
    return "Unable to parse error response (HTTP \(statusCode))"
}

/// Monitor Claude prompt cache performance from streaming usage data in AIRequestFunctions
func monitorClaudeStreamingCachePerformance(usage: ClaudeUsage) async {
    
#if DEV_DEBUG || DEBUG
    // Extract cache and usage data
    let inputTokens = usage.inputTokens
    let outputTokens = usage.outputTokens
    let cacheCreationInputTokens = usage.cacheCreationInputTokens ?? 0
    let cacheReadInputTokens = usage.cacheReadInputTokens ?? 0
    
    log("🔍 Claude Streaming Response Usage Analysis for Cache Performance:")
    log("📊 Usage Statistics:")
    log("   → Input tokens: \(inputTokens)")
    log("   → Output tokens: \(outputTokens)")
    
    // Analyze cache performance
    log("💾 Cache Performance Analysis:")
    if cacheCreationInputTokens > 0 {
        log("   ✅ Cache created with \(cacheCreationInputTokens) tokens")
        
        // Calculate potential savings
        let potentialSavings = Double(cacheCreationInputTokens) * 0.9 // 90% cost reduction for cached tokens
        log("   💰 Potential future savings: \(String(format: "%.0f", potentialSavings)) token-equivalents per request")
    }
    
    if cacheReadInputTokens > 0 {
        let cachePercentage = (Double(cacheReadInputTokens) / Double(inputTokens)) * 100
        log("   🚀 Cache hit! \(cacheReadInputTokens) tokens read from cache (\(String(format: "%.1f", cachePercentage))%)")
        
        // Calculate actual savings
        let actualSavings = Double(cacheReadInputTokens) * 0.9 // 90% cost reduction for cached tokens
        log("   💰 Cost savings: ~\(String(format: "%.0f", actualSavings)) token-equivalents")
    } else if inputTokens >= 1024 {
        log("   ❓ No cache hits detected")
        log("   → Cache may still be warming up for future requests")
    } else {
        log("   📏 Prompt too small for caching (\(inputTokens) < 1024 tokens)")
        log("   → Claude caching requires ≥1024 tokens")
        log("   → Consider consolidating static content")
    }
    
    // Log overall token usage
    let totalTokens = inputTokens + outputTokens
    log("🎯 Total usage: \(inputTokens) input + \(outputTokens) output = \(totalTokens) tokens")
    
    // Log to server for analytics
    log("Claude streaming cache performance - Created: \(cacheCreationInputTokens), Read: \(cacheReadInputTokens), Total: \(totalTokens)")
#endif
}
