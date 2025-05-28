//
//  ResponsesAPITestView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/27/25.
//

import SwiftUI
import Foundation
import SwiftyJSON

struct ResponseAPISchema: Encodable {
    var type: String = "object"
    var properties = StitchAIStepsSchema()
    
    // add a key for `defs`
    // needs to be encoded as "$defs" not just "defs"
    var defs = StitchAIStructuredOutputsDefinitions()
    
    var required: [String] = ["steps"]
    var additionalProperties: Bool = false
    var title: String = "VisualProgrammingActions"

    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case defs = "$defs"
        case required
        case additionalProperties
        case title
    }
}

struct ResponsesAPITestView: View {
    @State private var summaryDeltas: [String] = []
    @State private var streamedSteps: Steps = .init()

    let userPrompt: String = "Make an animating green rectangle"
    
    var body: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 600, height: 200)
                .overlay { Text("Inference call with prompt: \n \(self.userPrompt)") }

            HStack(alignment: .center) {
                ScrollView {
                    Text(self.summaryDeltas.joined())
                        .padding()
                }
                .frame(width: 600, height: 500)
                
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(self.streamedSteps, id: \.hashValue) { streamedStep in
                            Text(streamedStep.description)
                                .padding()
                            
                        }
                    }
                    
                }
                .frame(width: 600, height: 500)
            }
            
        }
        .onTapGesture {
            log("TAPPED")
            self.summaryDeltas = .init()
            self.streamedSteps = .init()
            Task(priority: .high) {
                do {
                    try await streamResponseWithReasoning(
                        apiKey: TEST_KEY,
                        userPrompt: self.userPrompt
                    )
                } catch {
                    print("Error while streaming:", error)
                }
            }
        }
    }
    
    @MainActor
    func streamResponseWithReasoning(
        apiKey: String,
        userPrompt: String
    ) async throws {
        // 1️⃣ Build the JSON payload
        let messages = [
            ChatMessage(role: "system", content: HARDCODED_SYSTEM_PROMPT),
            ChatMessage(role: "user", content: userPrompt)
        ]
        let payload = ResponsesCreateRequest(
    //        model: "o4-mini-2025-04-16",
            model: "ft:o4-mini-2025-04-16:ve::BaQU8UVH",
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
        
        let encodedPayload: Data = try JSONEncoder().encode(payload)
            
        // 2️⃣ Configure URLRequest
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)",                forHTTPHeaderField: "Authorization")
        request.setValue("application/json",                forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream",               forHTTPHeaderField: "Accept")
        request.httpBody = encodedPayload

        // 3️⃣ Open the byte-stream
        let (stream, _) = try await URLSession.shared.bytes(for: request)

        // 4️⃣ Parse SSE “data:” lines as they arrive
        // Buffers for parsing steps eagerly
        var allContentTokens: [String] = []
        var contentTokensSinceLastStep: [String] = []
        var buffer = ""
        for try await byte in stream {
            buffer.append(Character(UnicodeScalar(byte)))
            if buffer.hasSuffix("\n") {
                // log("had new line suffix")
                let line = buffer.trimmingCharacters(in: .newlines)
                buffer = ""

                // ignore SSE event lines
                if line.hasPrefix("event:") {
                    continue
                }
                // skip empty lines
                guard !line.isEmpty else {
                    continue
                }
                
                // extract JSON text: drop "data:" prefix if present, otherwise use the whole line
                let jsonText: String
                if line.hasPrefix("data:") {
                    // remove "data:" and any following whitespace
                    let startIndex = line.index(line.startIndex, offsetBy: 5)
                    jsonText = line[startIndex...].trimmingCharacters(in: .whitespaces)
    //                log("data prefix: jsonText is now: \(jsonText)")
                } else {
                    jsonText = line
                    // never hit?
    //                log("did not find data prefix: jsonText is now: \(jsonText)")
                }

                let jsonData = Data(jsonText.utf8)
                // Decode the "type" field to dispatch to the correct chunk struct
                struct SSEType: Codable {
                    let type: String
                }
                let decoder = JSONDecoder()
                do {
                    let typeContainer = try decoder.decode(SSEType.self, from: jsonData)
                    switch typeContainer.type {
                    case "response.created":
                        let chunk = try decoder.decode(ResponseCreated.self, from: jsonData)
                        log("created: \(chunk)")
                    case "response.in_progress":
                        let chunk = try decoder.decode(ResponseInProgress.self, from: jsonData)
                        log("in progress: \(chunk)")
                    case "response.output_item.added":
                        let chunk = try decoder.decode(ResponseOutputItemAdded.self, from: jsonData)
                        log("output item added: \(chunk)")
                    case "response.content_part.added":
                        let chunk = try decoder.decode(ResponseContentPartAdded.self, from: jsonData)
                        log("content part added: \(chunk)")
                    
                    
                    case "response.output_text.delta":
                        // Eagerly parse incoming deltas into Steps
                        let chunk = try decoder.decode(ResponseOutputTextDelta.self, from: jsonData)
                        let delta = chunk.delta
                        let trimmedChunk = chunk.delta.trimmingCharacters(in: .newlines)
                        log("response.output_text.delta: DELTA: \(trimmedChunk)")
                        allContentTokens.append(delta)
                        contentTokensSinceLastStep.append(delta)
                        // Try parsing a new Step from the buffered tokens
                        if let (newStep, newTokens) = parseStepFromTokenStream(tokens: contentTokensSinceLastStep) {
                            contentTokensSinceLastStep = newTokens
                            log("Eagerly parsed new Step: \(newStep)")
                            self.streamedSteps.append(newStep)
                        }
                    
                    case "response.reasoning_summary_text.delta":
                        let chunk = try decoder.decode(ResponseReasoningSummaryTextDelta.self, from: jsonData)
                        let trimmedChunk = chunk.delta.trimmingCharacters(in: .newlines)
                        log("response.reasoning_summary_text.delta: DELTA: \(trimmedChunk)")
                        // print(chunk.delta, terminator: "")
                        self.summaryDeltas.append(trimmedChunk)
                    
                    case "response.reasoning_summary_text.done":
                        let chunk = try decoder.decode(ResponseReasoningSummaryTextDone.self, from: jsonData)
                        log("reasoning summary done: \(chunk)")
                        self.summaryDeltas.append("\n\n")
                        
                    case "response.reasoning_summary_part.added":
                        let chunk = try decoder.decode(ResponseReasoningSummaryPartAdded.self, from: jsonData)
                        log("reasoning summary part added: \(chunk)")
                        self.summaryDeltas.append("\n")
                    
                    case "response.reasoning_summary_part.done":
                        let chunk = try decoder.decode(ResponseReasoningSummaryPartDone.self, from: jsonData)
                        log("reasoning summary part done: \(chunk)")
                        self.summaryDeltas.append("\n")
                    
                    case "response.content_part.done":
                        let chunk = try decoder.decode(ResponseContentPartDone.self, from: jsonData)
                        log("content part done: \(chunk)")
                    case "response.output_item.done":
                        let chunk = try decoder.decode(ResponseOutputItemDone.self, from: jsonData)
                        log("output item done: \(chunk)")
                    case "response.output_text.done":
                        let chunk = try decoder.decode(ResponseOutputTextDone.self, from: jsonData)
                        log("output text done: \(chunk)")
                    case "response.failed":
                        log("Response failed: \(jsonText)")
                        // fatalErrorIfDebug("response failed!")
                        // let failed = try decoder.decode(ResponseFailedChunk.self, from: jsonData)
    //                    throw NSError(
    //                        domain: "ResponsesAPI",
    //                        code: 1,
    //                        userInfo: [NSLocalizedDescriptionKey: failed.response.error.message]
    //                    )
                    default:
                        // Unknown type — ignore or log if desired
                        log("Unhandled SSE type: \(typeContainer.type)")
                        log("Unhandled SSE type: \(jsonText)")
                        // fatalErrorIfDebug()
                    }
                } catch {
                    // Decode error
                    log("Failed to decode JSON for line: \(jsonText) — error: \(error)")
                    // fatalErrorIfDebug()
                }
            }
            
        } // for try await byte in stream
        
        log("STREAM ENDED")
    }
}



// MARK: – Models

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
    let schema: JSON
    // let schema: ResponseAPISchema // StitchAIStructuredOutputsPayload //JSONSchema
}

/// Each streamed SSE chunk from the Responses API.
struct ResponseStreamChunk: Codable {
    let token: String
    let done: Bool
    let model: String
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case token, done, model
        case finishReason = "finish_reason"
    }
}

/// A streamed SSE chunk carrying a reasoning summary.
struct ReasoningSummaryChunk: Codable {
    let summary: String
}

// MARK: – Streaming Function

/// Streams tokens (plus reasoning) from the Responses API.


/// {"type":"response.created", …}
struct ResponseCreated: Codable, Equatable, Hashable {
    var sequenceNumber: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
    }
}

/// {"type":"response.in_progress", …}
struct ResponseInProgress: Codable, Equatable, Hashable {
    var sequenceNumber: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
    }
}

/// {"type":"response.output_item.added", …}
struct ResponseOutputItemAdded: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case outputIndex = "output_index"
    }
}

/// {"type":"response.content_part.added", …}
struct ResponseContentPartAdded: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
    }
}

/// {"type":"response.output_text.delta", …}
struct ResponseOutputTextDelta: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int
    var delta: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case delta
    }
}

/// {"type":"response.reasoning_summary_text.delta", …}
struct ResponseReasoningSummaryTextDelta: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int
    var delta: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
        case delta
    }
}

/// {"type":"response.reasoning_summary_text.done", …}
struct ResponseReasoningSummaryTextDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int
    // no `delta` here since it's a “done” marker

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
    }
}

/// {"type":"response.reasoning_summary_part.added", …}
struct ResponseReasoningSummaryPartAdded: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
    }
}

/// {"type":"response.reasoning_summary_part.done", …}
struct ResponseReasoningSummaryPartDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
    }
}

/// {"type":"response.output_item.done", …}
struct ResponseOutputItemDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var outputIndex: Int
    var item: OutputItemDoneItem

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case outputIndex = "output_index"
        case item
    }
}

struct OutputItemDoneItem: Codable, Equatable, Hashable {
    var id: String
    var type: String
    var summary: [SummaryText]

    enum CodingKeys: String, CodingKey {
        case id, type, summary
    }
}

struct SummaryText: Codable, Equatable, Hashable {
    var type: String
    var text: String

    enum CodingKeys: String, CodingKey {
        case type
        case text
    }
}

/// {"type":"response.output_text.done", …}
struct ResponseOutputTextDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int
    var text: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case text
    }
}

/// {"type":"response.content_part.done", …}
struct ResponseContentPartDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int
    var part: ContentPart

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case part
    }
}

struct ContentPart: Codable, Equatable, Hashable {
    var type: String
    var annotations: [String]  // or a more specific type if known
    var text: String

    enum CodingKeys: String, CodingKey {
        case type, annotations, text
    }
}
