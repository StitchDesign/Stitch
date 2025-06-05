//
//  AIGraphCreationRequest_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

enum AIGraphCreationRequestBody_V0 {    
    // https://platform.openai.com/docs/api-reference/making-requests
    struct AIGraphCreationRequestBody : StitchAIRequestBodyFormattable {
        let model: String
        let n: Int = 1
        let temperature: Double = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        let response_format = CurrentAIGraphCreationResponseFormat.AIGraphCreationResponseFormat()
        let messages: [OpenAIMessage]
        let stream: Bool = AIGraphCreationRequest.willStream
        
        init(secrets: Secrets,
             userPrompt: String) {
            let systemPrompt = CurrentAIGraphCreationSystemPrompt.systemPrompt
            let structuredOutputs = CurrentAIGraphCreationResponseFormat.AIGraphCreationResponseFormat().json_schema.schema
            let structuredOutputsString = try! structuredOutputs.encodeToPrintableString()
            
            self.model = secrets.openAIModel
            self.messages = [
                .init(role: .system,
                      content: systemPrompt + "Make sure your response follows this schema: \(structuredOutputsString)"),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}
