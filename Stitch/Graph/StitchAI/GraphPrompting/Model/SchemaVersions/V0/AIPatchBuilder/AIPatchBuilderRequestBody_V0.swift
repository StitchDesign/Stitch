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
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let messages: [OpenAIMessage]
        let tools: [OpenAIFunction]
        let tool_choice = StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction.patchBuilder.function
        let stream: Bool = false
        
        init(userPrompt: String,
//             layerDataList: [CurrentAIGraphData.LayerData],
             toolMessages: [OpenAIMessage],
             requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
             systemPrompt: String) throws {
            let assistantPrompt = try StitchAIManager.aiPatchBuilderSystemPromptGenerator()
            
            self.tools = requestType.allOpenAIFunctions
            
            self.messages = [.init(role: .system,
                                   content: systemPrompt),
                             .init(role: .assistant,
                                   content: assistantPrompt)] +
            toolMessages
        }
    }
    
    struct AIPatchBuilderFunctionInputs: Encodable {
        let swiftui_source_code: String
        let layer_data: [AIGraphData_V0.LayerData]
    }
}
