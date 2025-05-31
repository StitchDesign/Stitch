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
         userPrompt: String,
         systemPrompt: String) {
        
        self.model = secrets.openAIModel
        self.n = 1
        self.temperature = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        self.response_format = StitchAIResponseFormat()
        self.messages = [
            .init(role: .system,
                  content: systemPrompt + "Make sure your response follows this schema: \(ENCODED_OPEN_AI_STRUCTURED_OUTPUTS)"),
            .init(role: .user,
                  content: userPrompt)
        ]
        
        // We always stream
        self.stream = true
    }
}

struct EditJsNodeRequest: OpenAIRequestable {
    let model: String
    let n: Int
    let temperature: Double
    let response_format: EditJsNodeResponseFormat
    let messages: [OpenAIMessage]
    
    init(secrets: Secrets,
         userPrompt: String,
         systemPrompt: String) throws {
        let responseFormat = EditJsNodeResponseFormat()
        let structuredOutputs = responseFormat.json_schema.schema
        
        self.model = secrets.openAIModel
        self.n = 1
        self.temperature = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
        self.response_format = responseFormat
        self.messages = [
            .init(role: .system,
                  content: systemPrompt + "Make sure your response follows this schema: \(try structuredOutputs.encodeToPrintableString())"),
            .init(role: .user,
                  content: userPrompt)
        ]
    }
}

struct StitchAIResponseFormat: OpenAIResponseFormatable {
    let type = "json_schema"
    let json_schema = StitchAIJsonSchema()
}

struct EditJsNodeResponseFormat: OpenAIResponseFormatable {
    let type = "json_schema"
    let json_schema = EditJsNodeStructuredOutputsPayload()
}

struct StitchAIJsonSchema: OpenAIJsonSchema {
    let name = StitchAIStructuredOutputsSchema.title
    let schema = StitchAIStructuredOutputsPayload()
}

//struct EditJsNodeJsonSchema: OpenAIJsonSchema {
//    let schema = OpenAISchema(type: .object,
//                              properties: JsNodeSettingsSchema(),
//                              required: ["script", "inputDefinitions", "outputDefinitions"])
//}
