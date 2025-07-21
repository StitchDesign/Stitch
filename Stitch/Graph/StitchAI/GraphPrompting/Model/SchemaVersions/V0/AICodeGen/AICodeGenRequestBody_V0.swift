//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenRequestBody_V0 {
    //    static let systemMarkdownLocation = "AIGraphBuilderSystemPrompt_V0"
    
    //    static func getSystemPrompt() throws -> String {
    //        guard let systemMarkdownUrl = Bundle.main.url(forResource: Self.systemMarkdownLocation,
    //                                                      withExtension: "md") else {
    //            throw StitchAIStreamingError.markdownNotFound
    //        }
    //
    //        let systemPrompt = try String(contentsOf: systemMarkdownUrl,
    //                                      encoding: .utf8)
    //        return systemPrompt
    //    }
    
    struct AICodeGenRequestBody: StitchAIRequestableFunctionBody {
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools: [OpenAIFunction]
        let tool_choice: OpenAIFunction
        let stream: Bool = false
    }
}

extension AICodeGenRequestBody_V0.AICodeGenRequestBody {
    init(currentGraphData: CurrentAIGraphData.GraphData,
         systemPrompt: String) throws {
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilder.function
        
        let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .userPrompt)
        
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
   
    init(userPrompt: String,
         systemPrompt: String) throws {
        self.tools = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt.allOpenAIFunctions
        self.tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilderFromImage.function
        
        let codeGenAssistantPrompt = try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: .imagePrompt)
        
        self.messages = [
            .init(role: .system,
                  content: systemPrompt),
            .init(role: .system,
                  content: codeGenAssistantPrompt),
            .init(role: .user,
                  content: userPrompt)
        ]
    }
}
