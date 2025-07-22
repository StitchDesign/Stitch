//
//  AICodeEditRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/19/25.
//

import SwiftUI

enum AICodeEditBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeEditRequestBody: StitchAIRequestableFunctionBody {
        static let markdownLocation = "AICodeGenSystemPrompt_V0"
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestType
            .userPrompt.allOpenAIFunctions
        let tool_choice: OpenAIFunction
        let stream: Bool = false
        
        
        
        // TODO: MOVE TO EXISTING FUNCTION BODY STRUCT
        
        
        init(userPrompt: String,
             toolMessages: [OpenAIMessage],
             systemPrompt: String) {
            self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeEditor.function
            
            self.messages = [
                .init(role: .system,
                      content: systemPrompt)
            ] +
            toolMessages + [
                .init(role: .user,
                      content: userPrompt)
            ]
        }
        
        // init used for calling the edit code function
        init(prevMessages: [OpenAIMessage]) throws {
            self.messages = prevMessages + [try AICodeEditRequest.createAssistantPrompt()]
            self.tool_choice = .init(type: .none)
        }
    }
}
