//
//  AIGraphCreationRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

enum AIGraphCreationRequestError: Error {
    case emptySteps
    case validationFailed(StitchAIStepHandlingError)
}

struct AIGraphCreationRequest: StitchAIRequestable {
    typealias InitialDecodedResult = AIGraphCreationContentJSON
    
    private static let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIGraphCreationRequestBody
    static let willStream: Bool = true
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         secrets: Secrets,
         config: OpenAIRequestConfig = .default,
         graph: GraphState) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config

        // Construct http payload
        self.body = AIGraphCreationRequestBody(secrets: secrets,
                                               userPrompt: prompt)
    }
    
    @MainActor
    static func createAndMakeRequest(prompt: String,
                                     aiManager: StitchAIManager,
                                     document: StitchDocumentViewModel) throws {
        guard let secrets = document.aiManager?.secrets else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        let graph = document.visibleGraph
        
        do {
            let request = try AIGraphCreationRequest(prompt: prompt,
                                                     secrets: secrets,
                                                     graph: graph)
            
            // Main request logic
            request.handleRequest(document: document)
        } catch {
            fatalErrorIfDebug("Unable to generate Stitch AI prompt with error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        print("🤖 🔥 GENERATE AI NODE - STARTING AI GENERATION MODE 🔥 🤖")
        print("🤖 Prompt: \(self.userPrompt)")
        
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        if canShareData {
            Task(priority: .background) { [weak aiManager] in
                try? await aiManager?.uploadUserPromptRequestToSupabase(
                    prompt: self.userPrompt,
                    requestId: self.id)
            }
        }
        
        // Make sure current task is completely wiped
        aiManager.cancelCurrentRequest()
        aiManager.currentTask = nil
        
        // Clear previous streamed steps
        document.llmRecording.streamedSteps = .init()
        
        // Clear the previous actions
        document.llmRecording.actions = .init()

        // Set flag to indicate this is from AI generation
        document.insertNodeMenuState.isFromAIGeneration = true
        
        print("🤖 isFromAIGeneration set to: \(document.insertNodeMenuState.isFromAIGeneration)")
        
        // Track initial graph state
        document.llmRecording.initialGraphState = document.visibleGraph.createSchema()
        
        // Track task object
        aiManager.currentTask = CurrentAITask(task: requestTask)
    }
    
    static func validateRepopnse(decodedResult: AIGraphCreationContentJSON) throws -> [any StepActionable] {
        let convertedSteps = decodedResult.steps.map { $0.parseAsStepAction() }
        
        // Catch steps that didn't convert
        let nonConvertedSteps = convertedSteps.compactMap { $0.error }
        guard nonConvertedSteps.isEmpty else {
            log("makeNonStreamedRequest: empty results")
            throw AIGraphCreationRequestError.emptySteps
        }
        
        return convertedSteps.compactMap(\.value)
    }
    
    @MainActor
    func onSuccessfulRequest(result: [any StepActionable],
                             aiManager: StitchAIManager,
                             document: StitchDocumentViewModel) throws {
        if let error = document.validateAndApplyActions(result) {
            fatalErrorIfDebug(error.description)
            throw AIGraphCreationRequestError.validationFailed(error)
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
