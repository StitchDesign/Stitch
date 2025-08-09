//
//  OpenAIFunctionRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/23/25.
//

import SwiftUI

//struct OpenAIFunctionRequest: StitchAIFunctionRequestable {
//    let id: UUID
//    let type: StitchAIRequestBuilder_V0.StitchAIRequestType
//    let config: OpenAIRequestConfig = .default
//    let body: OpenAIRequestBody
//    let willStream: Bool = false
//    
//    // Object for creating actual code creation request
//    init(id: UUID,
//         functionType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
//         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
//         messages: [OpenAIMessage]) {
//        self.id = id
//        self.type = requestType
//        self.body = .init(messages: messages,
//                          type: requestType,
//                          functionType: functionType)
//    }
//}

// TODO: move
struct OpenAIChatCompletionRequest: StitchAIChatCompletionRequestable {
    let id: UUID
    let type: StitchAIRequestBuilder_V0.StitchAIRequestType
    let config: OpenAIRequestConfig = .default
    let body: OpenAIRequestBody
    let willStream: Bool = false
    
    // Object for creating actual code creation request
    init(id: UUID,
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         dataGlossaryPrompt: String,
         assistantPrompt: String,
         inputs: any Encodable) throws {
        let messages: [OpenAIMessage] = [
            .init(role: .system,
                  content: assistantPrompt),
            
            // MARK: for improved results, make data glossary after main system prompt
            
            .init(role: .system,
                  content: dataGlossaryPrompt),
            .init(role: .user,
                  content: try inputs.encodeToString())
        ]
        
        self.id = id
        self.type = requestType
        self.body = .init(messages: messages)
    }
}

// Vision-enabled chat completion request for multimodal input (text + images)
struct OpenAIVisionChatCompletionRequest: StitchAIChatCompletionRequestable {
    let id: UUID
    let type: StitchAIRequestBuilder_V0.StitchAIRequestType
    let config: OpenAIRequestConfig = .default
    let body: OpenAIVisionRequestBody
    let willStream: Bool = false
    
    // Object for creating request with vision capabilities
    init(id: UUID,
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         dataGlossaryPrompt: String,
         assistantPrompt: String,
         textInput: String,
         base64Image: String?) throws {
        
        var userContentArray: [OpenAIUserContentItem] = []
        
        // Add text content
        userContentArray.append(.text(OpenAIUserTextContent(text: textInput)))
        
        // Add image if provided
        if let imageData = base64Image {
            userContentArray.append(.image(OpenAIUserImageContent(base64Image: imageData)))
        }
        
        let messages: [OpenAIVisionMessage] = [
            .init(role: .system, content: .text(assistantPrompt)),
            .init(role: .system, content: .text(dataGlossaryPrompt)),
            .init(role: .user, content: .contentArray(userContentArray))
        ]
        
        self.id = id
        self.type = requestType
        self.body = .init(messages: messages)
    }
}

extension OpenAIChatCompletionRequest {
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: String) throws -> String {
        // Nothing to do here
        decodedResult
    }
    
    @MainActor
    func onSuccessfulRequest(result: String,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        print("AI request successful: \(result)")
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: String,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No JavaScript node support for streaming.")
    }
    
    static func buildResponse(from streamingChunks: [String]) throws -> String {
        streamingChunks.joined()
    }
}

// Vision-enabled message structure
struct OpenAIVisionMessage: Encodable {
    let role: OpenAIRole
    let content: OpenAIVisionContent
}

enum OpenAIVisionContent: Encodable {
    case text(String)
    case contentArray([OpenAIUserContentItem])
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .contentArray(let items):
            var container = encoder.singleValueContainer()
            try container.encode(items)
        }
    }
}

enum OpenAIUserContentItem: Encodable {
    case text(OpenAIUserTextContent)
    case image(OpenAIUserImageContent)
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let textContent):
            try textContent.encode(to: encoder)
        case .image(let imageContent):
            try imageContent.encode(to: encoder)
        }
    }
}

// Vision-enabled request body
struct OpenAIVisionRequestBody: Encodable {
    var model: String = "o4-mini-2025-04-16" // Use Vision-capable model
    var n: Int = 1
    var temperature: Double = 1.0
    var messages: [OpenAIVisionMessage]
    var stream: Bool = false
}

extension OpenAIVisionChatCompletionRequest {
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: String) throws -> String {
        // Nothing to do here
        decodedResult
    }
    
    @MainActor
    func onSuccessfulRequest(result: String,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        print("AI vision request successful: \(result)")
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: String,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No streaming support for vision requests.")
    }
    
    static func buildResponse(from streamingChunks: [String]) throws -> String {
        streamingChunks.joined()
    }
}

struct OpenAIChatCompletionStructuredOutputsRequest<ResponseFormat: OpenAIResponseFormatable>: StitchAIChatCompletionRequestable {
    let id: UUID
    let type: StitchAIRequestBuilder_V0.StitchAIRequestType
    let config: OpenAIRequestConfig = .default
    let body: OpenAIStructuredOutputsRequestBody<ResponseFormat>
    let willStream: Bool = false
    
    // Object for creating actual code creation request
    init(id: UUID,
         requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
         systemPrompt: String,
         assistantPrompt: String,
         responseFormat: ResponseFormat,
         inputs: any Encodable) throws {
        let messages: [OpenAIMessage] = [
            .init(role: .system,
                  content: systemPrompt),
            .init(role: .system,
                  content: assistantPrompt),
            .init(role: .user,
                  content: try inputs.encodeToString())
        ]
        
        self.id = id
        self.type = requestType
        self.body = .init(response_format: responseFormat,
                          messages: messages)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: CurrentAIGraphData.PatchData) throws -> CurrentAIGraphData.PatchData {
        // Nothing to do here
        decodedResult
    }
    
    @MainActor
    func onSuccessfulRequest(result: CurrentAIGraphData.PatchData,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        print("AI request successful: \(result)")
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: CurrentAIGraphData.PatchData,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No streaming support.")
    }
    
    static func buildResponse(from streamingChunks: [CurrentAIGraphData.PatchData]) throws -> CurrentAIGraphData.PatchData {
        fatalError("No streaming support.")
    }
}
