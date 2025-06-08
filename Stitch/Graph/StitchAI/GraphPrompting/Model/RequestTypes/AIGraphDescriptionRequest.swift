//
//  AIGraphDescriptionRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AIGraphDescriptionRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String              // User's input prompt
    let config: OpenAIRequestConfig     // Request configuration settings
    let body: AIGraphDescriptionRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default,
         document: StitchDocumentViewModel,
         nodeId: NodeId) throws {
        guard let secrets = document.aiManager?.secrets else {
            throw StitchAIManagerError.secretsNotFound
        }
        
        self.init(prompt: prompt,
                  secrets: secrets,
                  config: config,
                  graph: document.visibleGraph,
                  nodeId: nodeId)
    }
    
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState,
         nodeId: NodeId) {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = AIGraphDescriptionRequestBody(secrets: secrets,
                                                  userPrompt: prompt)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateRepopnse(decodedResult: String) throws -> String {
        // Nothing to do here
        decodedResult
    }
    
    @MainActor
    func onSuccessfulRequest(result: String,
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        print("AI request successful: \(result)")
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: String,
                                   currentAttempt: Int) {
        fatalErrorIfDebug("No JavaScript node support for streaming.")
    }
}

