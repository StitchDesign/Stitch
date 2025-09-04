//
//  OpenAIResponsesRequest.swift
//  Stitch
//
//  Created by Claude Code on 8/30/25.
//

import Foundation
import SwiftUI

/// Request implementation using OpenAI's Responses endpoint with streaming support
struct OpenAIResponsesRequest {
    let id: UUID
    let requestType: StitchAIRequestBuilder_V0.StitchAIRequestType
    let dataGlossaryPrompt: String
    let assistantPrompt: String
    let textInput: String
    let base64Image: String?
    let model: OpenAIModel
    let verbosity: OpenAIVerbosity
    let reasoningEffort: OpenAIReasoningEffort
    let originalCodeLength: Int
    
    init(id: UUID,
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         dataGlossaryPrompt: String,
         assistantPrompt: String,
         textInput: String,
         base64Image: String? = nil,
         model: OpenAIModel,
         verbosity: OpenAIVerbosity,
         reasoningEffort: OpenAIReasoningEffort,
         originalCodeLength: Int) {
        self.id = id
        self.requestType = requestType
        self.dataGlossaryPrompt = dataGlossaryPrompt
        self.assistantPrompt = assistantPrompt
        self.textInput = textInput
        self.base64Image = base64Image
        self.model = model
        self.verbosity = verbosity
        self.reasoningEffort = reasoningEffort
        self.originalCodeLength = originalCodeLength
    }
    
    func request(document: StitchDocumentViewModel,
                 aiManager: StitchAIManager) async throws -> String {
        guard let secrets = try? Secrets() else {
            // TODO: handle failure
            fatalError("OpenAI Responses: No secrets found")
        }
        
        return try await performStreamingRequest(document: document, 
                                                 aiManager: aiManager, 
                                                 secrets: secrets)
    }
    
    @MainActor
    private func performStreamingRequest(document: StitchDocumentViewModel,
                                         aiManager: StitchAIManager,
                                         secrets: Secrets) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            // TODO: handle failure
            fatalError("OpenAI Responses: Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body using correct Responses API format
        var requestBody: [String: Any] = [
            "model": model.asOpenAIModel, // Use actual model parameter
            "stream": true
        ]
        
        // Add reasoning parameters
        requestBody["reasoning"] = [
            "summary": "auto", //verbosity.toReasoningSummary(),
            "effort": reasoningEffort.toReasoningEffort()
        ]
                
        let instructions = """
        \(dataGlossaryPrompt)
        
        \(assistantPrompt)
        """
        
        requestBody["instructions"] = instructions
        
        // Build input using correct Responses API format
        if let imageData = base64Image {
            // Multimodal request - use array format with role-based messages
            requestBody["input"] = [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": textInput
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
            requestBody["input"] = textInput
        }
        
        // Log request details for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) {
            print("🔍 Total request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
            
            // Log readable request structure (truncated)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let truncatedRequest = jsonString.count > 2000 ? String(jsonString.prefix(2000)) + "...[TRUNCATED]" : jsonString
                print("📤 Outgoing Request: \(truncatedRequest)")
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
//        let eagerParsingThreshold = 30 // Parse every N delta events
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
                // TODO: handle failure
                fatalError("OpenAI Responses: No HTTP response")
            }
            
            guard httpResponse.statusCode == 200 else {
                // Capture detailed error response from API
                var errorData = Data()
                do {
                    for try await byte in asyncBytes {
                        errorData.append(byte)
                    }
                    
                    let errorString = String(data: errorData, encoding: .utf8) ?? "No error data"
                    print("🚨 API Error Response: \(errorString)")
                    
                    // Try to parse as JSON for structured error
                    if let errorJSON = try? JSONSerialization.jsonObject(with: errorData) {
                        print("🚨 Parsed Error JSON: \(errorJSON)")
                    }
                    
                    fatalError("OpenAI Responses: HTTP \(httpResponse.statusCode) - \(errorString)")
                } catch {
                    fatalError("OpenAI Responses: HTTP \(httpResponse.statusCode) - Could not read error response: \(error)")
                }
            }
            
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    let dataString = String(line.dropFirst(6))
                    
                    if dataString == "[DONE]" {
                        break
                    }
                    
                    if let data = dataString.data(using: .utf8) {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                await handleStreamingEvent(json: json,
                                                          streamingResponse: &streamingResponse,
                                                          accumulatedReasoning: &accumulatedReasoning,
                                                          document: document,
                                                          requestStartTime: requestStartTime,
                                                          firstReasoningTime: &firstReasoningTime,
                                                          firstCodeContentTime: &firstCodeContentTime,
                                                          responseCompletedTime: &responseCompletedTime,
                                                          tokenDeltaCount: &tokenDeltaCount,
                                                          eagerParsingThreshold: eagerParsingThreshold)
                            }
                        } catch {
                            // Ignore JSON parsing errors for individual chunks
                        }
                    }
                }
            }
            
            // Reset streaming state
            await MainActor.run {
                document.isStreamingResponses = false
                document.streamingReasoningText = ""
            }
            
            // Log comprehensive timing results
            print("⏱️ Streaming Timing Summary:")
            
            if let firstReasoningTime = firstReasoningTime {
                let timeToFirstReasoning = firstReasoningTime.timeIntervalSince(requestStartTime)
                print("   → First reasoning: \(String(format: "%.2f", timeToFirstReasoning)) seconds")
            } else {
                print("   → First reasoning: Not received")
            }
            
            if let firstCodeTime = firstCodeContentTime {
                let timeToFirstCode = firstCodeTime.timeIntervalSince(requestStartTime)
                print("   → First code content: \(String(format: "%.2f", timeToFirstCode)) seconds")
            } else {
                print("   → First code content: Not received")
            }
            
            if let completionTime = responseCompletedTime {
                let totalTime = completionTime.timeIntervalSince(requestStartTime)
                print("   → Response completed: \(String(format: "%.2f", totalTime)) seconds")
                
                // Calculate phase durations
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
    
    private func handleStreamingEvent(json: [String: Any],
                                      streamingResponse: inout String,
                                      accumulatedReasoning: inout String,
                                      document: StitchDocumentViewModel,
                                      requestStartTime: Date,
                                      firstReasoningTime: inout Date?,
                                      firstCodeContentTime: inout Date?,
                                      responseCompletedTime: inout Date?,
                                      tokenDeltaCount: inout Int,
                                      eagerParsingThreshold: Int) async {
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
                
                // TODO: explore eager parsing differently
//                if tokenDeltaCount >= eagerParsingThreshold {
//                    await attemptEagerParsing(streamingResponse: streamingResponse, document: document, originalCodeLength: originalCodeLength)
//                    tokenDeltaCount = 0 // Reset counter
//                }
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
                // TODO: handle failure
                fatalError("OpenAI Responses API Error: \(error)")
            }
        
        default:
            // Log unhandled reasoning events for debugging
            if eventType.contains("reasoning") {
                print("🧠 Unhandled reasoning event: \(eventType)")
            }
        }
    }
        
//    /// Attempts eager parsing of accumulated streaming response
//    private func attemptEagerParsing(streamingResponse: String, document: StitchDocumentViewModel, originalCodeLength: Int) async {
//        guard !streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
//            return
//        }
//        
//        // For genuine edits (originalCodeLength > 0), only parse when we reach 90% of original code length
//        if originalCodeLength > 0 {
//            let threshold = Double(originalCodeLength) * 0.9
//            let currentLength = Double(streamingResponse.count)
//            
//            if currentLength < threshold {
//                print("⏭️ Skipping eager parsing: \(streamingResponse.count) chars < 90% threshold (\(Int(threshold)) chars) of original (\(originalCodeLength) chars)")
//                return
//            } else {
//                print("🎯 90% threshold reached! Streaming: \(streamingResponse.count) chars, Original: \(originalCodeLength) chars, Threshold: \(Int(threshold)) chars")
//            }
//        } else {
//            print("🆕 New code creation: eager parsing at \(streamingResponse.count) characters (no original code to compare)")
//        }
//        
//        print("🔄 Attempting eager parsing with \(streamingResponse.count) characters...")
//        
//        do {
//            // Use existing SwiftUI parser (forgiving of incomplete code)
//            let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(streamingResponse)
//            
//            // Derive Stitch actions from parsed code
//            var actionsResult = await codeParserResult.deriveStitchActions(bindingDeclarations: codeParserResult.bindingDeclarations)
//            
//            // Clear caught errors to prevent showing them during eager parsing
//            actionsResult.caughtErrors.removeAll()
//            
//            // Apply partial results if we got meaningful layer data
//            if !actionsResult.graphData.layer_data_list.isEmpty {
//                print("✅ Eager parsing succeeded: found \(actionsResult.graphData.layer_data_list.count) layers")
//                
//                await MainActor.run {
//                    // Apply partial results to document
//                    Task(priority: .high) {
//                        await actionsResult.applyAIGraph(to: document, 
//                                                         viewStatePatchConnections: actionsResult.graphData.viewStatePatchConnections, 
//                                                         requestType: .userPrompt)
//                    }
//                }
//            } else {
//                print("⏭️ Eager parsing: no meaningful layers yet")
//            }
//        } catch {
//            // Silently ignore all parse failures during eager parsing - this is expected with incomplete code
//            // No logging to avoid showing silent errors while streaming
//        }
//    }
    
}

// MARK: - Extensions for OpenAI model configuration

extension OpenAIModel {
    var supportsReasoning: Bool {
        // Add logic to determine which models support reasoning
        switch self {
        case .gpt5, .gpt5Nano, .gpt5Mini, .o4Mini:
            return true
        }
    }
    
    var asOpenAIModel: String {
        self.rawValue
    }
}

// Verbosity is not the same as ReasoningSummary
extension OpenAIVerbosity {
    func toReasoningSummary() -> String {
        return "auto"
//        switch self {
//        case .low:
//            return "concise"
//        case .medium:
//            return "detailed"
//        case .high:
//            return "detailed"
//        default:
//            return "auto"
//        }
    }
}

extension OpenAIReasoningEffort {
    func toReasoningEffort() -> String {
        switch self {
        case .low:
            return "low"
        case .medium:
            return "medium"
        case .high:
            return "high"
        default:
            return "medium"
        }
    }
}
