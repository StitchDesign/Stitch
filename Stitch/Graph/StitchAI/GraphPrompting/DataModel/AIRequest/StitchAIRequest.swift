//
//  StitchAIRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/4/25.
//

import Foundation
import SwiftUI


struct StitchAIRequest: StitchAIRequestable {
    typealias InitialDecodedResult = StitchAIContentJSON
    
    private static let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    
    let id: UUID
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
        
        // Created and never changed, for the life of whole of the user's inference call
        self.id = .init()
        
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
    
    // i.e. "Start inference call by opening a stream"
    @MainActor
    static func createAndMakeRequest(prompt: String,
                                     canShareAIRetries: Bool,
                                     aiManager: StitchAIManager,
                                     document: StitchDocumentViewModel) throws {
        guard let secrets = document.aiManager?.secrets,
              let _ = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no secrets and/or aiManager")
            return
        }
        
        let graph = document.visibleGraph
        
        do {
            let request = try StitchAIRequest(prompt: prompt,
                                              secrets: secrets,
                                              graph: graph)
            
            
            // Log to Supabase
            // TODO: only do this if user has granted permission
            Task(priority: .high) { [weak document] in
                guard let aiManager = document?.aiManager else {
                    fatalErrorIfDebug()
                    return
                }
                
                try await aiManager.uploadUserPromptRequestToSupabase(
                    prompt: prompt,
                    requestId: request.id)
            }
            
            // Make the actual request
            request.makeRequest(canShareAIRetries: canShareAIRetries,
                                document: document)
        } catch {
            fatalErrorIfDebug("Unable to generate Stitch AI prompt with error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func makeRequest(canShareAIRetries: Bool,
                     document: StitchDocumentViewModel) {
        print("🤖 🔥 GENERATE AI NODE - STARTING AI GENERATION MODE 🔥 🤖")
        print("🤖 Prompt: \(self.userPrompt)")
        
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug("GenerateAINode: no aiManager")
            return
        }
        
        // Make sure current task is completely wiped
        aiManager.cancelCurrentRequest()
        aiManager.currentTask = nil
        
        // Clear previous streamed steps
        document.llmRecording.streamedSteps = .init()
        
        // Clear the previous actions
        document.llmRecording.actions = .init()
                
        // Set loading state
        withAnimation { // added
            document.insertNodeMenuState.isGeneratingAIResult = true
        }
        
        // Set flag to indicate this is from AI generation
        document.insertNodeMenuState.isFromAIGeneration = true
        
        print("🤖 isFromAIGeneration set to: \(document.insertNodeMenuState.isFromAIGeneration)")
        
        // Track initial graph state
        document.llmRecording.initialGraphState = document.visibleGraph.createSchema()
        
        // Create the task and set it on the manager
        aiManager.currentTask = CurrentAITask(task: aiManager.getOpenAITask(
            request: self,
            attempt: 1,
            document: document,
            canShareAIRetries: canShareAIRetries))
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
