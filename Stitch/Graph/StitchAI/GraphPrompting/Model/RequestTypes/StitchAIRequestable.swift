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
    associatedtype FinalDecodedResult
    // Type that's processed from streaming
    associatedtype TokenDecodedResult
    // Task object for request
    typealias RequestTask = Task<Void, Never>
    
    var id: UUID { get }
    var userPrompt: String { get }             // User's input prompt
    var config: OpenAIRequestConfig { get } // Request configuration settings
    var body: Body { get }
    static var willStream: Bool { get }
    
    /// Reports when a request is about to happen. Can be used to prepare the UI.
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask)
    
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
    @MainActor
    /// Main request handler for AI requests.
    func handleRequest(document: StitchDocumentViewModel) {
        guard let aiManager = document.aiManager else {
            return
        }
        
        let taskObject = aiManager.getOpenAITask(
            request: self,
            attempt: 1,
            document: document,
            canShareAIRetries: StitchStore.canShareAIData)
        
        // Prepare the UI, if necessary
        self.willRequest(document: document,
                         canShareData: StitchStore.canShareAIData,
                         requestTask: taskObject)
    }
    
    func getPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self.body)
    }
}
