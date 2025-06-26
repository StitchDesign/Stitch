//
//  AIPatchBuilderRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AIPatchBuilderRequestBody_V0 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AIPatchBuilderRequestBody: StitchAIRequestBodyFormattable {
        static let markdownLocation = "AIPatchBuilderSystemPrompt_V0"
        
        let model: String = "o4-mini-2025-04-16"
        let n: Int = 1
        let temperature: Double = 1.0
        let response_format = AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat()
        let messages: [OpenAIMessage]
        let stream: Bool = false
        
        init(userPrompt: String,
             swiftUiSourceCode: String,
             layerList: SidebarLayerList?) throws {
            let responseFormat = AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat()
            let structuredOutputs = responseFormat.json_schema.schema
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                    withExtension: "md") else {
                throw StitchAIStreamingError.markdownNotFound
            }
            
            let systemPrompt = try String(contentsOf: markdownUrl,
                                          encoding: .utf8)
            let fullSystemPrompt = "\(systemPrompt)\nUse the following structured outputs schema:\n\(try structuredOutputs.encodeToPrintableString())"
            
            let inputs = AIPatchBuilderRequestInputs(
                user_prompt: userPrompt,
                swiftui_source_code: swiftUiSourceCode,
                layer_list: layerList)
            let userInputsString = try inputs.encodeToPrintableString()
            
            self.messages = [
                .init(role: .system,
                      content: fullSystemPrompt),
                .init(role: .user,
                      content: userInputsString)
            ]
        }
    }
    
    struct AIPatchBuilderRequestInputs: Encodable {
        let user_prompt: String
        let swiftui_source_code: String
        let layer_list: SidebarLayerList?
        
        enum CodingKeys: String, CodingKey {
            case user_prompt
            case swiftui_source_code
            case layer_list
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(user_prompt, forKey: .user_prompt)
            try container.encode(swiftui_source_code, forKey: .swiftui_source_code)
            
            // Only encode if values were provided
            try container.encodeIfPresent(layer_list, forKey: .layer_list)
        }
    }
}
