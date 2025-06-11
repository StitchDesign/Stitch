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
    init(config: OpenAIRequestConfig = .default,
         document: StitchDocumentViewModel) throws {
        guard let secrets = document.aiManager?.secrets else {
            throw StitchAIManagerError.secretsNotFound
        }
        
        let steps = Self.deriveStepActionsFromSelectedState(document: document)
        
        // TODO: remove this step when schema improves
        let reducedSteps = steps.map(\.toStep)
        
        do {
            // Create user prompt using schema of actions composing of selected nodes
            let userPrompt = try reducedSteps.encodeToPrintableString()
            
            self.init(prompt: userPrompt,
                      secrets: secrets,
                      config: config,
                      graph: document.visibleGraph)
        } catch {
            fatalErrorIfDebug(error.localizedDescription)
            
            self.init(prompt: "",
                      secrets: secrets,
                      config: config,
                      graph: document.visibleGraph)
        }
    }
    
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState) {
        
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
    
    static func validateResponse(decodedResult: String) throws -> String {
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
    
    static func buildResponse(from streamingChunks: [String]) throws -> String {
        streamingChunks.joined()
    }
    
    @MainActor
    /// Determines step actions needed to replicated selected state.
    static func deriveStepActionsFromSelectedState(document: StitchDocumentViewModel) -> [any StepActionable] {
        let graph = document.visibleGraph
        let copiedComponent = graph
            .createCopiedComponent(groupNodeFocused: document.groupNodeFocused,
                                   selectedNodeIds: graph.selectedPatchAndLayerNodes)
        return StitchDocumentViewModel
            .deriveNewAIActions(newGraphEntity: copiedComponent.component.graphEntity,
                                visibleGraph: graph)
    }
}
