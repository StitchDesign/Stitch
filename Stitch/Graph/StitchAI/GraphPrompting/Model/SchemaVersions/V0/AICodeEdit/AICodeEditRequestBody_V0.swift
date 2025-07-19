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
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.allFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeEditor.function
        let stream: Bool = false
        
        init(userPrompt: String,
             toolMessages: [OpenAIMessage]) throws {
            let systemPrompt = try AICodeGenRequestBody_V0.getSystemPrompt()
            
            let assistantPrompt = """
                Modify SwiftUI source code based on the request from a user prompt. Use code returned from the last function caller. Adhere to previously defined rules regarding patch and layer behavior in Stitch.

                Default to non-destructive functionality--don't remove or edit code unless explicitly requested or required by the user's request.
                
                Adhere to the guidelines specified in this document:
                
                \(try StitchAIManager.aiCodeGenSystemPromptGenerator())
                """
            
            self.messages = [.init(role: .system,
                                   content: systemPrompt),
                             .init(role: .system,
                                   content: assistantPrompt)] +
            toolMessages + [
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}
