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
    
    associatedtype Body: StitchAIRequestBodyFormattable
    
    // Initial payload that's expected from OpenAI response
    associatedtype InitialDecodedResult
    
    // Final data type after all processing, may equal InitialDecodedResult
    associatedtype FinalDecodedResult
    
    // Type that's processed from streaming
    associatedtype TokenDecodedResult
    
    typealias ResponseFormat = Body.ResponseFormat
    
    var id: UUID { get } // Id for the submitted prompt
    var userPrompt: String { get }             // User's input prompt
    var systemPrompt: String { get }
    var config: OpenAIRequestConfig { get } // Request configuration settings
    var body: Body { get }
    static var willStream: Bool { get }
    
    @MainActor
    func makeRequest(canShareAIRetries: Bool,
                     document: StitchDocumentViewModel)
    
    /// Validates a successfully decoded response and outputs a possibly different data structure.
    static func validateRepopnse(decodedResult: InitialDecodedResult) throws -> FinalDecodedResult
    
    @MainActor
    func onSuccessfulRequest(result: FinalDecodedResult,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws
    
    @MainActor
    func onSuccessfulDecodingChunk(result: TokenDecodedResult,
                                   currentAttempt: Int)
}

extension StitchAIRequestable {
    func getPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self.body)
    }
}
