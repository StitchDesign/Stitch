//
//  StitchAIRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI
import StitchSchemaKit

//https://platform.openai.com/docs/api-reference/making-requests
struct StitchAIRequest: OpenAIRequestable {
    let model: String
    let n: Int
    let temperature: Double
    let response_format: StitchAIResponseFormat
    let messages: [OpenAIMessage]
    
    init(secrets: Secrets,
         userPrompt: String,
         systemPrompt: String) throws {
        let responseFormat = StitchAIResponseFormat()
        let structuredOutputs = responseFormat.json_schema.schema
        
        self.model = secrets.openAIModel
        self.n = 1
        self.temperature = 0.0
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

struct StitchAIJsonSchema: OpenAIJsonSchema {
    let name = StitchAIStructuredOutputsSchema.title
    let schema = StitchAIStructuredOutputsPayload()
}
