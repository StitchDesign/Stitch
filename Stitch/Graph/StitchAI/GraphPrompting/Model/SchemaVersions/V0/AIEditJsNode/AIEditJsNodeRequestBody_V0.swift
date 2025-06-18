//
//  AIEditJsNodeRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import SwiftUI

enum AIEditJsNodeRequestBody_V0 {
    struct AIEditJsNodeRequestBody: StitchAIRequestBodyFormattable {        
        let model: String
        let n: Int = 1
        let temperature: Double = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        let response_format = AIEditJsNodeResponseFormat_V0.AIEditJsNodeResponseFormat()
        let messages: [OpenAIMessage]
        let stream = false
        
        init(secrets: Secrets,
             userPrompt: String) {
            let responseFormat = AIEditJsNodeResponseFormat_V0.AIEditJsNodeResponseFormat()
            let structuredOutputs = responseFormat.json_schema.schema
            let systemPrompt = AIEditJsNodeSystemPrompt_V0.systemPrompt
            
            self.model = secrets.openAIModelJsNode
            self.messages = [
                .init(role: .system,
                      content: systemPrompt + "Make sure your response follows this schema: \(try! structuredOutputs.encodeToPrintableString())"),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}

enum AIJavaScriptSupabase_V0 {
    struct InferenceResult: SupabaseGenerable {
        static let tablename = "dataset_v0_javascript"
        
        let user_id: String
        let request_id: UUID
        let user_prompt: String
        let javascript_settings: JavaScriptNodeSettings
    }
}
