//
//  StitchAIRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI
import StitchSchemaKit
    
// If we cannot encode the structured outputs properly, we should not even be able to run the app.
let OPEN_AI_STRUCTURED_OUTPUTS = StitchAIResponseFormat().json_schema.schema
let ENCODED_OPEN_AI_STRUCTURED_OUTPUTS = try! OPEN_AI_STRUCTURED_OUTPUTS.encodeToPrintableString()

// https://platform.openai.com/docs/api-reference/making-requests
struct StitchAIRequest: OpenAIRequestable {
    let model: String
    let n: Int
    let temperature: Double
    let response_format: StitchAIResponseFormat
    let messages: [OpenAIMessage]
    let stream: Bool

    init(secrets: Secrets,
         userPrompt: UserAIPrompt,
         systemPrompt: String) {
        
        self.model = secrets.openAIModel
        self.n = 1
        self.temperature = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        self.response_format = StitchAIResponseFormat()
        self.messages = [
            .init(role: .system,
                  content: systemPrompt + "Make sure your response follows this schema: \(ENCODED_OPEN_AI_STRUCTURED_OUTPUTS)"),
            .init(role: .user,
                  content: userPrompt.value)
        ]
        
        // We always stream
        self.stream = true
    }
}

struct StitchAIResponseFormat: OpenAIResponseFormatable {
    let type = "json_schema"
    let json_schema = StitchAIJsonSchema()
}

struct StitchAIJsonSchema: OpenAIJsonSchema {
    let name = StitchAIStructuredOutputsSchema.title
    let schema = StitchAIStructuredOutputsPayload()
}
