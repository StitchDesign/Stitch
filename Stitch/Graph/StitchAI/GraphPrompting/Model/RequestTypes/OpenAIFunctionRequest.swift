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
         systemPrompt: String,
         assistantPrompt: String,
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
