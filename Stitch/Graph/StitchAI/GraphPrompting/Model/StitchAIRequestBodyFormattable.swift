//
//  StitchAIRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI
import StitchSchemaKit

protocol StitchAIRequestBodyFormattable: Encodable {
    associatedtype ResponseFormat: Encodable
    
    var model: String { get }
    var n: Int { get }
    var temperature: Double { get }
    var response_format: ResponseFormat { get }
    var messages: [OpenAIMessage] { get }
    var stream: Bool { get }
}

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
