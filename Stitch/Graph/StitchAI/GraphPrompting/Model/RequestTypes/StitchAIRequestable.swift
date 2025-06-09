//
//  StitchAIRequestable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/31/25.
//

import SwiftUI
import StitchSchemaKit

// If this is not a valid URL, we should not even be able to run the app.
let OPEN_AI_BASE_URL_STRING = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_BASE_URL: URL = URL(string: OPEN_AI_BASE_URL_STRING)!

// Note: an event is usually not a long-lived data structure; but this is used for retry attempts.
/// Main event handler for initiating OpenAI API requests
protocol StitchAIRequestable: Sendable where InitialDecodedResult: Decodable, TokenDecodedResult: Decodable {
    associatedtype Body: Encodable
    // Initial payload that's expected from OpenAI response
    associatedtype InitialDecodedResult
    // Final data type after all processing, may equal InitialDecodedResult
    associatedtype FinalDecodedResult: Sendable
    // Type that's processed from streaming
    associatedtype TokenDecodedResult: Sendable
    typealias RequestResponsePayload = (FinalDecodedResult, URLResponse)
    // Task object for request
    typealias RequestTask = Task<FinalDecodedResult, any Error>
    
    var id: UUID { get }
    var userPrompt: String { get }             // User's input prompt
    var config: OpenAIRequestConfig { get } // Request configuration settings
    var body: Body { get }
    static var willStream: Bool { get }
    
    /// Validates a successfully decoded response and outputs a possibly different data structure.
    static func validateRepopnse(decodedResult: InitialDecodedResult) throws -> FinalDecodedResult
    
    @MainActor
    func onSuccessfulDecodingChunk(result: TokenDecodedResult,
                                   currentAttempt: Int)
    
    // Given a streaming "chunk" build the full response
    static func buildResponse(from streamingChunks: [TokenDecodedResult]) throws -> InitialDecodedResult
}

extension StitchAIRequestable {
    func getPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self.body)
    }
}
