//
//  AICodeEditRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/20/25.
//

import SwiftUI

struct AICodeEditRequest: StitchAIFunctionRequestable {
    let type: StitchAIRequestBuilder_V0.StitchAIRequestType = .userPrompt
    
    let id: UUID
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeEditBody_V0.AICodeEditRequestBody
    static let willStream: Bool = false
    
    init(id: UUID,
         prompt: String,
         toolMessages: [OpenAIMessage],
         systemPrompt: String,
         config: OpenAIRequestConfig = .default) {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = id
        
        self.config = config
        
        // Construct http payload
        self.body = AICodeEditBody_V0.AICodeEditRequestBody(
            userPrompt: prompt,
            toolMessages: toolMessages,
            systemPrompt: systemPrompt)
    }

    // Initializer used for invoking the edit request
    init(id: UUID,
         prevMessages: [OpenAIMessage]) throws {
        self.id = id
        self.config = .default
        self.body = try .init(prevMessages: prevMessages)
    }
    
    
    static func createAssistantPrompt() throws -> OpenAIMessage {
        let assistantPrompt = """
            Modify SwiftUI source code based on the request from a user prompt. Use code returned from the last function caller. Adhere to previously defined rules regarding patch and layer behavior in Stitch.

            Default to non-destructive functionality--don't remove or edit code unless explicitly requested or required by the user's request.
            
            Adhere to the guidelines specified in this document:
            
            \(try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .userPrompt))
            """
        
        return .init(role: .assistant,
                     content: assistantPrompt)
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
