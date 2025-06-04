//
//  EditJSONRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/4/25.
//

import Foundation
import SwiftUI


struct EditJSNodeRequest: StitchAIRequestable {
    let id: UUID
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
         config: OpenAIRequestConfig = .default,
         document: StitchDocumentViewModel,
         nodeId: NodeId) throws {
        guard let secrets = document.aiManager?.secrets else {
            throw StitchAIManagerError<EditJSNodeRequest>.secretsNotFound
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
        
        // Created and never changed, for the life of whole of the user's inference call
        self.id = .init()
        
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
    
    @MainActor
    func makeRequest(canShareAIRetries: Bool,
                     document: StitchDocumentViewModel) {
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        // Create the task and set it on the manager
        aiManager.currentTask = CurrentAITask(task: aiManager.getOpenAITask(
            request: self,
            attempt: 1,
            document: document,
            canShareAIRetries: canShareAIRetries))
    }
    
    static func validateRepopnse(decodedResult: JavaScriptNodeSettingsAI) throws -> JavaScriptNodeSettings {
        .init(script: decodedResult.script,
              inputDefinitions: decodedResult.input_definitions.map(JavaScriptPortDefinition.init),
              outputDefinitions: decodedResult.output_definitions.map(JavaScriptPortDefinition.init))
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
