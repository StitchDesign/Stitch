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
             layerDataList: [CurrentAIGraphData.LayerData],
             toolMessages: [OpenAIMessage],
             requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
             systemPrompt: String) throws {
            let assistantPrompt = try StitchAIManager.aiPatchBuilderSystemPromptGenerator()
            
            self.tools = requestType.allOpenAIFunctions
            
            let userInputs = AIPatchBuilderFunctionInputs(
                layer_data_list: try layerDataList.encodeToPrintableString()
            )
            
            self.messages = [
                .init(role: .system,
                      content: systemPrompt)
            ] +
            toolMessages + [
                .init(role: .system,
                      content: assistantPrompt),
                .init(role: .user,
                      content: try userInputs.encodeToPrintableString())
            ]
        }
    }
    
    struct AIPatchBuilderFunctionInputs: Encodable {
        // MARK: already provided in previous tools
//        let swiftui_source_code: String
        
        // MARK: no nesting support in structured schema, using string for now
        let layer_data_list: String
//        let layer_data: [AIGraphData_V0.LayerData]
    }
    
    struct AIPatchBuilderFunctionInputsSchema: Encodable {
        let swiftui_source_code = OpenAISchema(type: .string)
        let layer_data_list = OpenAISchema(type: .string)
    }
}
