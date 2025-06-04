//
//  AIEditJsNodeRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

enum AIEditJsNodeRequestBody_V0 {
    struct AIEditJsNodeRequestBody: StitchAIRequestBodyFormattable {
        let model: String
        let n: Int = 1
        let temperature: Double = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        let response_format = CurrentAIEditJsNodeResponseFormat.AIEditJsNodeResponseFormat()
        let messages: [OpenAIMessage]
        let stream = AIEditJSNodeRequest.willStream
        
        init(secrets: Secrets,
             userPrompt: String) {
            let responseFormat = CurrentAIEditJsNodeResponseFormat.AIEditJsNodeResponseFormat()
            let structuredOutputs = responseFormat.json_schema.schema
            let systemPrompt = CurrentAIEditJsSystemPrompt.systemPrompt
            
            self.model = secrets.openAIModel
            self.messages = [
                .init(role: .system,
                      content: systemPrompt + "Make sure your response follows this schema: \(try! structuredOutputs.encodeToPrintableString())"),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}
