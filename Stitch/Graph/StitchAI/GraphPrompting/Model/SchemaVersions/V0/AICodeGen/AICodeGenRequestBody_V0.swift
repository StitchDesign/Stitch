//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {
    static let systemMarkdownLocation = "AIGraphBuilderSystemPrompt_V0"

    static func getSystemPrompt() throws -> String {
        guard let systemMarkdownUrl = Bundle.main.url(forResource: Self.systemMarkdownLocation,
                                                      withExtension: "md") else {
            throw StitchAIStreamingError.markdownNotFound
        }
        
        let systemPrompt = try String(contentsOf: systemMarkdownUrl,
                                      encoding: .utf8)
        return systemPrompt
    }
    
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeGenRequestBody: StitchAIRequestableFunctionBody {
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.allFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeBuilder.function
        let stream: Bool = false
        
        init(currentGraphData: CurrentAIGraphData.GraphData) throws {
            let systemPrompt = try AICodeGenRequestBody_V0.getSystemPrompt()
            let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator()
            
            let inputsString = try currentGraphData.encodeToPrintableString()
            
            print("AICodeGenRequestBody: incoming graph data:\n\((try? currentGraphData.encodeToPrintableString()) ?? "")")
            
            self.messages = [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .system,
                      content: codeGenAssistantPrompt),
                .init(role: .user,
                      content: inputsString)
            ]
        }
    }
    
    // Claude API request body structure for initial SwiftUI code generation
    struct ClaudeCodeGenRequestBody: Encodable {
        let model: String = "claude-3-5-sonnet-20241022"
        let max_tokens: Int = 4096
        let temperature: Double = 1.0
        let system: String
        let messages: [ClaudeMessage]
        
        init(currentGraphData: CurrentAIGraphData.GraphData) throws {
            // Get system prompts
            let systemPrompt = try AICodeGenRequestBody_V0.getSystemPrompt()
            let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator()
            
            self.system = systemPrompt + "\n\n" + codeGenAssistantPrompt
            
            let inputsString = try currentGraphData.encodeToPrintableString()
            
            self.messages = [
                ClaudeMessage(role: "user", content: [
                    ClaudeMessageContent.text(inputsString)
                ])
            ]
        }
    }
    
    struct ClaudeMessage: Encodable {
        let role: String
        let content: [ClaudeMessageContent]
    }
    
    struct ClaudeMessageContent: Encodable {
        let type: String
        let text: String?
        let source: ClaudeImageSource?
        
        static func text(_ text: String) -> ClaudeMessageContent {
            ClaudeMessageContent(type: "text", text: text, source: nil)
        }
        
        static func image(type: String, source: ClaudeImageSource) -> ClaudeMessageContent {
            ClaudeMessageContent(type: type, text: nil, source: source)
        }
    }
    
    struct ClaudeImageSource: Encodable {
        let type: String
        let media_type: String
        let data: String
    }
}
