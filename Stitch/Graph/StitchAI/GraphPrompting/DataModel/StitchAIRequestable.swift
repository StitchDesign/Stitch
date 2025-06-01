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
    
    var userPrompt: String { get }             // User's input prompt
    var systemPrompt: String { get }
    var config: OpenAIRequestConfig { get } // Request configuration settings
    var body: Body { get }
    static var willStream: Bool { get }
    
    
    ///
    static func validateRepopnse(decodedResult: InitialDecodedResult) throws -> FinalDecodedResult
    
    @MainActor
    func onSuccessfulRequest(result: FinalDecodedResult,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws
    
    @MainActor
    func onSuccessfulDecodingChunk(result: TokenDecodedResult,
                                   currentAttempt: Int)
    
    func getPayloadData() throws -> Data
}

extension StitchAIRequestable {
    func getPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self.body)
    }
}

struct StitchAIRequest: StitchAIRequestable {
    typealias InitialDecodedResult = StitchAIContentJSON
    
    private static let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    
    let userPrompt: String             // User's input prompt
    let systemPrompt: String
    let config: OpenAIRequestConfig // Request configuration settings
    let body: StitchAIRequestBody
    static let willStream: Bool = true
    
    enum StitchAIRequestError: Error {
        case emptySteps
        case validationFailed(StitchAIStepHandlingError)
    }
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState) throws {
        self.userPrompt = prompt
        self.config = config
        
        // Load system prompt from bundled file
        let systemPrompt = try StitchAIManager.stitchAISystemPrompt(graph: graph)
        self.systemPrompt = systemPrompt
        
        // Construct http payload
        self.body = StitchAIRequestBody(secrets: secrets,
                                        userPrompt: prompt,
                                        systemPrompt: systemPrompt)
    }
    
    static func validateRepopnse(decodedResult: StitchAIContentJSON) throws -> [any StepActionable] {
        let convertedSteps = decodedResult.steps.map { $0.parseAsStepAction() }
        
        // Catch steps that didn't convert
        let nonConvertedSteps = convertedSteps.compactMap { $0.error }
        guard nonConvertedSteps.isEmpty else {
            log("makeNonStreamedRequest: empty results")
            throw StitchAIRequestError.emptySteps
        }
        
        return convertedSteps.compactMap(\.value)
    }
    
    @MainActor
    func onSuccessfulRequest(result: [any StepActionable],
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        if let error = document.validateAndApplyActions(result) {
            fatalErrorIfDebug(error.description)
            throw StitchAIRequestError.validationFailed(error)
        }
        
        aiManager.openAIStreamingCompleted(originalPrompt: self.userPrompt,
                                           request: self,
                                           document: document)
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: Step,
                                   currentAttempt: Int) {
        dispatch(ChunkProcessed(
            newStep: result,
            request: self,
            currentAttempt: currentAttempt
        ))
    }
}

struct EditJSNodeRequest: StitchAIRequestable {
    let userPrompt: String             // User's input prompt
    let systemPrompt: String
    let config: OpenAIRequestConfig // Request configuration settings
    let body: EditJsNodeRequestBody
    static let willStream: Bool = false
    
    // Tracks origin node of request
    let nodeId: NodeId
    
    enum EditJSNodeRequestError: Error {
        case noNodeFound
    }
    
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState,
         nodeId: NodeId) {
        self.userPrompt = prompt
        self.config = config
        self.nodeId = nodeId
        
        // Load system prompt from bundled file
        let systemPrompt = StitchAIManager.jsNodeSystemPrompt()
        self.systemPrompt = systemPrompt
        
        // Construct http payload
        self.body = EditJsNodeRequestBody(secrets: secrets,
                                          userPrompt: prompt,
                                          systemPrompt: systemPrompt)
    }
    
    static func validateRepopnse(decodedResult: JavaScriptNodeSettings) throws -> JavaScriptNodeSettings {
        // TBD
        decodedResult
    }
    
    @MainActor
    func onSuccessfulRequest(result: JavaScriptNodeSettings,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        guard let patchNode = document.visibleGraph.getNode(self.nodeId)?.patchNode else {
            log("EditJSNodeRequest error: no node found.")
            throw EditJSNodeRequestError.noNodeFound
        }
        
        return patchNode.processNewJavascript(response: result)
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: JavaScriptNodeSettings,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No JavaScript node support for streaming.")
    }
}
