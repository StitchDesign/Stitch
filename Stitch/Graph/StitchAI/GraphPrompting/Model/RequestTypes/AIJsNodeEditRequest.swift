//
//  AIJsNodeEditRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AIEditJSNodeRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIEditJsNodeRequestBody
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
         nodeId: NodeId) {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        self.nodeId = nodeId
        
        // Construct http payload
        self.body = AIEditJsNodeRequestBody(secrets: secrets,
                                            userPrompt: prompt)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: JavaScriptNodeSettingsAI) throws -> JavaScriptNodeSettings {
        .init(suggestedTitle: decodedResult.suggested_title,
              script: decodedResult.script,
              inputDefinitions: try decodedResult.input_definitions.map(JavaScriptPortDefinition.init),
              outputDefinitions: try decodedResult.output_definitions.map(JavaScriptPortDefinition.init))
    }
    
    // TODO: support streaming
    @MainActor
    func onSuccessfulDecodingChunk(result: JavaScriptNodeSettings,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No JavaScript node support for streaming.")
    }
    
    // TODO: support streaming
    static func buildResponse(from streamingChunks: [JavaScriptNodeSettings]) throws -> CurrentJavaScriptNodeSettingsAI.JavaScriptNodeSettingsAI {
        // Unsupported
        fatalError()
    }
}
