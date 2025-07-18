//
//  AIPatchBuilderRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AIPatchBuilderRequestBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AIPatchBuilderRequestBody: StitchAIRequestableFunctionBody {
//        static let markdownLocation = "AIPatchBuilderSystemPrompt_V0"
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
//        let response_format = AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat()
        let messages: [OpenAIMessage]
        let tools = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.allFunctions
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.patchBuilder.function
        let stream: Bool = false
        
        init(userPrompt: String,
             layerDataList: [CurrentAIGraphData.LayerData],
             prevMessages: [OpenAIMessage]) throws {
//            let responseFormat = AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat()
//            let structuredOutputs = responseFormat.json_schema.schema
//            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
//                                                    withExtension: "md") else {
//                throw StitchAIStreamingError.markdownNotFound
//            }
//            
//            let assistantPrompt = try String(contentsOf: markdownUrl,
//                                          encoding: .utf8)
//            let fullSystemPrompt = "\(systemPrompt)\nUse the following structured outputs schema:\n\(try structuredOutputs.encodeToPrintableString())"
            
//            let layerData = try layerDataList.encodeToPrintableString()
            
            
            let assistantPrompt = try StitchAIManager.aiPatchBuilderSystemPromptGenerator()
            
            self.messages = prevMessages
            + [
//                .init(role: .user,
//                      content: layerData)
                .init(role: .assistant,
                      content: assistantPrompt),
//                .init(role: .user,
//                      content: userInputsString)
            ]
        }
    }
    
    struct AIPatchBuilderFunctionInputs: Encodable {
        let swiftui_source_code: String
        let layer_data: [AIGraphData_V0.LayerData]
    }
}
