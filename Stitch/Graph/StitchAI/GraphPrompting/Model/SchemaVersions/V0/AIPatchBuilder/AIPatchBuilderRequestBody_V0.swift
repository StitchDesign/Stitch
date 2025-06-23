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
        
        let model: String = "gpt-4o-2024-08-06"
        let n: Int = 1
        let temperature: Double = 0.0
        let response_format = AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat()
        let messages: [OpenAIMessage]
        let stream: Bool = false
        
        init(secrets: Secrets,
             userPrompt: String) throws {
            let responseFormat = AIPatchBuilderResponseFormat_V0.AIPatchBuilderResponseFormat()
            let structuredOutputs = responseFormat.json_schema.schema
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                    withExtension: "md") else {
                throw StitchAIStreamingError.markdownNotFound
            }
            
            let systemPrompt = try String(contentsOf: markdownUrl,
                                          encoding: .utf8)
            
            self.messages = [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}
