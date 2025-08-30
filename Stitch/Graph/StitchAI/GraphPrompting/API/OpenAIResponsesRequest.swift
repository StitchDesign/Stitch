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
    
    init(id: UUID,
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         dataGlossaryPrompt: String,
         assistantPrompt: String,
         textInput: String,
         base64Image: String? = nil,
         model: OpenAIModel,
         verbosity: OpenAIVerbosity,
         reasoningEffort: OpenAIReasoningEffort) {
        self.id = id
        self.requestType = requestType
        self.dataGlossaryPrompt = dataGlossaryPrompt
        self.assistantPrompt = assistantPrompt
        self.textInput = textInput
        self.base64Image = base64Image
        self.model = model
        self.verbosity = verbosity
        self.reasoningEffort = reasoningEffort
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
        
        // Build request body using StreamingDemoView format for compatibility
        var requestBody: [String: Any] = [
            "model": "o4-mini", // Use working model from StreamingDemoView
            "stream": true
        ]
        
        // Add reasoning parameters matching StreamingDemoView
        requestBody["reasoning"] = [
            "summary": "auto",
            "effort": "medium"
        ]
        
        // Build messages array with system message
        var messages: [[String: Any]] = []
        
        // Create system message with size validation
        let systemContent = createOptimizedSystemMessage(
            dataGlossary: dataGlossaryPrompt,
            assistant: assistantPrompt,
            textInputSize: textInput.count,
            imageSize: base64Image?.count ?? 0
        )
        
        messages.append([
            "role": "system",
            "content": systemContent
        ])
        
        // User message
        let userContent: Any
        if let imageData = base64Image {
            // For image requests, use multimodal content
            userContent = [
                [
                    "type": "text",
                    "text": textInput
                ],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(imageData)"
                    ]
                ]
            ]
        } else {
            // For text-only requests, use simple string content
            userContent = textInput
        }
        
        messages.append([
            "role": "user",
            "content": userContent
        ])
        
        requestBody["input"] = messages
        
        // Log total request size
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) {
            print("🔍 Total request body: \(jsonData.count) bytes (\(jsonData.count/1024)KB)")
            if jsonData.count > 100000 { // > 100KB
                print("⚠️ Request size over 100KB - may cause HTTP 400")
            }
        }
        
        // Set initial streaming state
        document.isStreamingResponses = true
        document.streamingReasoningText = "Thinking..."
        
        // Accumulate response data
        var streamingResponse = ""
        var accumulatedReasoning = ""
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // TODO: handle failure
                fatalError("OpenAI Responses: No HTTP response")
            }
            
            guard httpResponse.statusCode == 200 else {
                // TODO: handle failure  
                fatalError("OpenAI Responses: HTTP \(httpResponse.statusCode)")
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
                                                          document: document)
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
                                      document: StitchDocumentViewModel) async {
        guard let eventType = json["type"] as? String else { return }
        
        switch eventType {
        case "response.output_text.delta":
            if let delta = json["delta"] as? String {
                streamingResponse += delta
            }
        
        case "response.reasoning_summary_text.delta":
            if let delta = json["delta"] as? String {
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
    
    /// Creates system message with size logging
    private func createOptimizedSystemMessage(dataGlossary: String,
                                            assistant: String, 
                                            textInputSize: Int,
                                            imageSize: Int) -> String {
        
        // Calculate estimated total request size
        let baseRequestSize = 1000 // Rough estimate for JSON structure, model, etc.
        let fullSystemSize = dataGlossary.count + assistant.count + 10 // +10 for newlines
        let totalEstimatedSize = baseRequestSize + fullSystemSize + textInputSize + imageSize
        
        print("🔍 System message size analysis:")
        print("🔍 dataGlossaryPrompt: \(dataGlossary.count) characters")
        print("🔍 assistantPrompt: \(assistant.count) characters") 
        print("🔍 textInput: \(textInputSize) characters")
        if imageSize > 0 {
            print("🔍 base64Image: \(imageSize) characters")
        }
        print("🔍 estimated total request: \(totalEstimatedSize) bytes (\(totalEstimatedSize/1024)KB)")
        
        // Always use full system prompts - no truncation
        return """
        \(dataGlossary)
        
        \(assistant)
        """
    }
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

extension OpenAIVerbosity {
    func toReasoningSummary() -> String {
        switch self {
        case .low:
            return "brief"
        case .medium:
            return "auto"  
        case .high:
            return "detailed"
        default:
            return "auto"
        }
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
