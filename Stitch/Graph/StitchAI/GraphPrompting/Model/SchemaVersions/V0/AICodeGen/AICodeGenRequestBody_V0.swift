//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AICodeGenFromGraphRequestBody_V0 {
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
    
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AICodeGenFromGraphRequestBody: StitchAIRequestableFunctionBody {
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt.allOpenAIFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilder.function
        let stream: Bool = false
        
        @MainActor
        init(currentGraphData: CurrentAIGraphData.GraphData,
             graph: GraphState) throws {
            let systemPrompt = try StitchAIManager
                .stitchAIGraphBuilderSystem(graph: graph,
                                            requestType: .userPrompt)       
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
    
    struct AICodeGenFromImageRequestBody: StitchAIRequestableFunctionBody {
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestType.imagePrompt.allOpenAIFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.codeBuilderFromImage.function
        let stream: Bool = false
        
        @MainActor
        init(currentGraphData: CurrentAIGraphData.GraphData,
             graph: GraphState) throws {
            let systemPrompt = try StitchAIManager
                .stitchAIGraphBuilderSystem(graph: graph,
                                            requestType: .imagePrompt)
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
}
