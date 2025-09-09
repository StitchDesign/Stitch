//
//  OpenAIStreamingRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/9/25.
//

import SwiftUI

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
        log("🔍 Total request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
        
        // Log readable request structure (truncated)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            let truncatedRequest = jsonString.count > 2000 ? String(jsonString.prefix(2000)) + "...[TRUNCATED]" : jsonString
            log("📤 Outgoing OpenAI Request: \(truncatedRequest)")
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
        
        // log comprehensive timing summary
        let totalDuration = Date().timeIntervalSince(requestStartTime)
        log("⏱️ OpenAI Streaming Request Timing Summary:")
        log("   → Total request duration: \(String(format: "%.2f", totalDuration)) seconds")
        
        if let completionTime = responseCompletedTime {
            log("   → Response completed: \(String(format: "%.2f", completionTime.timeIntervalSince(requestStartTime))) seconds after start")
            
            // Calculate phase durations if we have all milestones
            if let firstReasoningTime = firstReasoningTime, let firstCodeTime = firstCodeContentTime {
                let reasoningPhase = firstCodeTime.timeIntervalSince(firstReasoningTime)
                let codePhase = completionTime.timeIntervalSince(firstCodeTime)
                log("   → Reasoning phase duration: \(String(format: "%.2f", reasoningPhase)) seconds (first code - first reasoning)")
                log("   → Code generation phase duration: \(String(format: "%.2f", codePhase)) seconds (completed - first code)")
            }
        } else {
            log("   → Response completed: Not received")
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
                log("🚀 First code content received after \(String(format: "%.2f", timeToFirstCode)) seconds: \"\(delta.prefix(50))\(delta.count > 50 ? "..." : "")\"")
            }
            streamingResponse += delta
            
            // Eager parsing: increment counter and attempt parsing at threshold
            tokenDeltaCount += 1
        }
    
    case "response.content_part.added":
        // This indicates a new content part is starting (might be code output)
        if let part = json["part"] as? [String: Any],
           let partType = part["type"] as? String {
            log("📝 Content part started: \(partType)")
            if partType == "output_text" && firstCodeContentTime == nil {
                // This is likely the start of actual code output
                log("🎯 Output text part detected - code content should start soon")
            }
        }
    
    case "response.reasoning_summary_text.delta":
        if let delta = json["delta"] as? String {
            // Record timing for first reasoning text
            if firstReasoningTime == nil && !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                firstReasoningTime = Date()
                let timeToFirstReasoning = firstReasoningTime!.timeIntervalSince(requestStartTime)
                log("🧠 First reasoning received after \(String(format: "%.2f", timeToFirstReasoning)) seconds: \"\(delta.prefix(50))\(delta.count > 50 ? "..." : "")\"")
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
        log("✅ Response completed after \(String(format: "%.2f", totalTime)) seconds")
        
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
                log("💻 First code content received: \(String(format: "%.2f", timeToFirstCode)) seconds")
            }
            
            streamingResponse += delta
            tokenDeltaCount += 1
        }
    
    default:
        // Log unhandled reasoning events for debugging
        if eventType.contains("reasoning") {
            log("🧠 Unhandled reasoning event: \(eventType)")
        } else if eventType.contains("output") || eventType.contains("content") {
            log("📄 Unhandled content event: \(eventType)")
        } else {
            log("❓ Unhandled event type: \(eventType)")
        }
    }
}
