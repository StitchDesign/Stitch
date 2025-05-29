//
//  ReasoningAIStreaming.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/28/25.
//

import Foundation
import SwiftUI
import SwiftyJSON


// MARK: models and helpers for *making the initial request* to the OpenAI Responses API


// Force unwrap because if we can't create a URL from the string-url,
// then the app shouldn't even be running.
let OPEN_AI_RESPONSES_API_URL = URL(string: "https://api.openai.com/v1/responses")!

func getURLRequestForResponsesAPI(userPrompt: String,
                                  apiKey: String,
                                  model: String) -> URLRequest? {
    
    let messages = [
        ChatMessage(role: "system",
                    content: HARDCODED_SYSTEM_PROMPT),
        ChatMessage(role: "user",
                    content: userPrompt)
    ]
    
    let payload = ResponsesCreateRequest(
//        model: "o4-mini-2025-04-16",
        model: model,
        input: messages,
        reasoning: .init(effort: "high", summary: "detailed"),
        text: TextOptions(
            format: TextFormat(
                type: "json_schema",
                name: "ui",
                strict: true,
                schema: JSON(rawValue: try! StitchAIStructuredOutputsPayload().encodeToData())!
            )
        ),
        stream: true
    )

    
    switch Result(catching: { try JSONEncoder().encode(payload) }) {
    
    case .failure(let error):
        // TODO: what to do with this error?
        fatalErrorIfDebug("Could not encode payload. Error: \(error)")
        return nil
        
    case .success(let encodedPayload):
        var request = URLRequest(url: OPEN_AI_RESPONSES_API_URL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)",
                         forHTTPHeaderField: "Authorization")
        request.setValue("application/json",
                         forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream",
                         forHTTPHeaderField: "Accept")
        request.httpBody = encodedPayload
        return request
    }
}

/// A single message in the `input` array.
struct ChatMessage: Codable {
    let role: String      // e.g. "system" or "user"
    let content: String
}

/// The POST body for the Responses “create” call.
struct ResponsesCreateRequest: Encodable {
    let model: String                  // e.g. "o4-mini-2025-04-16"
    let input: [ChatMessage]           // system+user messages
    let reasoning: ReasoningOptions    // how much effort & summary style
    let text: TextOptions              // text formatting options
    let stream: Bool                   // true for SSE

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case reasoning
        case text
        case stream
    }

    struct ReasoningOptions: Codable {
        let effort: String             // e.g. "medium"
        let summary: String            // e.g. "detailed"
    }
}
/// Configuration for text output formatting.
struct TextOptions: Encodable {
    let format: TextFormat
}

/// Specifies the format type, naming, strictness, and schema.
struct TextFormat: Encodable {
    let type: String         // e.g. "json_schema"
    let name: String         // e.g. "ui"
    let strict: Bool
    
    // TODO: what type should we actually use here? perferenc
    let schema: JSON
    // let schema: ResponseAPISchema // StitchAIStructuredOutputsPayload //JSONSchema
}
