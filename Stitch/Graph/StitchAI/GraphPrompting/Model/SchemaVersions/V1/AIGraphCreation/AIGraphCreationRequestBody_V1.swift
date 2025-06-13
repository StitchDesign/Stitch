//
//  AIGraphCreationRequest_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

enum AIGraphCreationRequestBody_V1 {
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AIGraphCreationRequestBody : StitchAIRequestBodyFormattable {
        static let markdownLocation = "AIGraphCreationSystemPrompt_V1"
        
        let model: String
        let n: Int = 1
        let temperature: Double = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        let response_format = CurrentAIGraphCreationResponseFormat.AIGraphCreationResponseFormat()
        let messages: [OpenAIMessage]
        let stream: Bool = true
        
        init(secrets: Secrets,
             userPrompt: String) throws {
            guard let markdownUrl = Bundle.main.url(forResource: Self.markdownLocation,
                                                    withExtension: "md") else {
                throw StitchAIStreamingError.markdownNotFound
            }
            
            let systemPrompt = try String(contentsOf: markdownUrl,
                                          encoding: .utf8)
            
            self.model = secrets.openAIModelGraphCreation
            self.messages = [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}
