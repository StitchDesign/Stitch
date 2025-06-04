////
////  ReasoningAIStreaming.swift
////  Stitch
////
////  Created by Christian J Clampitt on 5/28/25.
////
//
//import Foundation
//import SwiftUI
//import SwiftyJSON
//
//
//// MARK: models and helpers for *making the initial request* to the OpenAI Responses API
//
//
///// A single message in the `input` array.
//struct ChatMessage: Codable {
//    let role: String      // e.g. "system" or "user"
//    let content: String
//}
//
///// The POST body for the Responses “create” call.
//struct ResponsesCreateRequest: Encodable {
//    let model: String                  // e.g. "o4-mini-2025-04-16"
//    let input: [ChatMessage]           // system+user messages
//    let reasoning: ReasoningOptions    // how much effort & summary style
//    let text: TextOptions              // text formatting options
//    let stream: Bool                   // true for SSE
//
//    enum CodingKeys: String, CodingKey {
//        case model
//        case input
//        case reasoning
//        case text
//        case stream
//    }
//
//    struct ReasoningOptions: Codable {
//        let effort: String             // e.g. "medium"
//        let summary: String            // e.g. "detailed"
//    }
//}
///// Configuration for text output formatting.
//struct TextOptions: Encodable {
//    let format: TextFormat
//}
//
///// Specifies the format type, naming, strictness, and schema.
//struct TextFormat: Encodable {
//    let type: String         // e.g. "json_schema"
//    let name: String         // e.g. "ui"
//    let strict: Bool
//    
//    // TODO: what type should we actually use here? perferenc
//    let schema: JSON
//    // let schema: ResponseAPISchema // StitchAIStructuredOutputsPayload //JSONSchema
//}
