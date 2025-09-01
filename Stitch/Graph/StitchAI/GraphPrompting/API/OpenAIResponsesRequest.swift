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
        
        // Add instructions (replaces system message)
        let instructions = createOptimizedSystemMessage(
            dataGlossary: dataGlossaryPrompt,
            assistant: assistantPrompt,
            textInputSize: textInput.count,
            imageSize: base64Image?.count ?? 0
        )
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
