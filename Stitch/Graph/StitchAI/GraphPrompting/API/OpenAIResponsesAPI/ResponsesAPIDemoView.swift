//
//  ResponsesAPIDemoView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/27/25.
//

import SwiftUI
import Foundation
import SwiftyJSON

struct ResponsesAPIDemoView: View {
    
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
                        apiKey: "",
                        userPrompt: self.userPrompt
                    )
                } catch {
                    print("Error while streaming:", error)
                }
            }
        }
    }
    
    @MainActor
    func streamResponseWithReasoning(apiKey: String,
                                     userPrompt: String) async throws {

        // Build the JSON payload and configure URLRequest
        guard let request = getURLRequestForResponsesAPI(
            userPrompt: userPrompt,
            apiKey: apiKey,
            // model: "o4-mini-2025-04-16")
            model: "ft:o4-mini-2025-04-16:ve::BaQU8UVH") else {
            fatalErrorIfDebug()
            // TODO: return
            return
        }
        
        
        // Open the byte-stream
        let (stream, _) = try await URLSession.shared.bytes(for: request)

        
        // Parse SSE “data:” lines as they arrive
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
                        if let (newStep, newTokens) = StitchAIRequest.decodeFromTokenStream(tokens: contentTokensSinceLastStep) {
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
