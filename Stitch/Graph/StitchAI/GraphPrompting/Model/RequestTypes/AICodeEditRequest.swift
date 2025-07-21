//
//  AICodeEditRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/20/25.
//

import SwiftUI

struct AICodeEditRequest: StitchAIFunctionRequestable {
    static let aiService: AIServiceType = .openAI
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeEditBody_V0.AICodeEditRequestBody
    static let willStream: Bool = false
    
    init(id: UUID,
         prompt: String,
         toolMessages: [OpenAIMessage],
         systemPrompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = id
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeEditBody_V0.AICodeEditRequestBody(
            userPrompt: prompt,
            toolMessages: toolMessages,
            systemPrompt: systemPrompt)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: [OpenAIToolCallResponse]) throws -> [OpenAIToolCallResponse] {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: [OpenAIToolCallResponse],
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [[OpenAIToolCallResponse]]) throws -> [OpenAIToolCallResponse] {
        // Unsupported
        fatalError()
    }
}
