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

protocol StitchAIRequestBodyFormattable: Encodable {
    associatedtype ResponseFormat: Encodable
    
    var model: String { get }
    var n: Int { get }
    var temperature: Double { get }
    var response_format: ResponseFormat { get }
    var messages: [OpenAIMessage] { get }
    var stream: Bool { get }
}

// https://platform.openai.com/docs/api-reference/making-requests
struct StitchAIRequestBody : StitchAIRequestBodyFormattable {
    let model: String
    let n: Int = 1
    let temperature: Double = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
    let response_format = StitchAIResponseFormat()
    let messages: [OpenAIMessage]
    let stream: Bool = StitchAIRequest.willStream
    
    init(secrets: Secrets,
         userPrompt: String,
         systemPrompt: String) {
        self.model = secrets.openAIModel
        self.messages = [
            .init(role: .system,
                  content: systemPrompt + "Make sure your response follows this schema: \(ENCODED_OPEN_AI_STRUCTURED_OUTPUTS)"),
            .init(role: .user,
                  content: userPrompt)
        ]
    }
}

struct EditJsNodeRequestBody: StitchAIRequestBodyFormattable {
    let model: String
    let n: Int = 1
    let temperature: Double = FeatureFlags.STITCH_AI_REASONING ? 1.0 : 0.0
    let response_format = EditJsNodeResponseFormat()
    let messages: [OpenAIMessage]
    let stream = EditJSNodeRequest.willStream
    
    init(secrets: Secrets,
         userPrompt: String,
         systemPrompt: String) {
        let responseFormat = EditJsNodeResponseFormat()
        let structuredOutputs = responseFormat.json_schema.schema
        
        self.model = secrets.openAIModel
        self.messages = [
            .init(role: .system,
                  content: systemPrompt + "Make sure your response follows this schema: \(try! structuredOutputs.encodeToPrintableString())"),
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
    let json_schema = EditJsNodeJsonSchema()
}

struct StitchAIJsonSchema: OpenAIJsonSchema {
    let name = StitchAIStructuredOutputsSchema.title
    let schema = StitchAIStructuredOutputsPayload()
}

struct EditJsNodeJsonSchema: OpenAIJsonSchema {
    let name = "EditJSNode"
    let schema = EditJsNodeStructuredOutputsPayload()
}
