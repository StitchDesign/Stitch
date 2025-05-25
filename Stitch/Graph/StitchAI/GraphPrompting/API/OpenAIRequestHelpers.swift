//
//  OpenAIRequestHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/7/25.
//

import Foundation

struct ChunkProcessed: StitchDocumentEvent {
    let newStep: Step
    let request: OpenAIRequest
    let currentAttempt: Int
    
    func handle(state: StitchDocumentViewModel) {
        log("ChunkProcessed: newStep: \(newStep)")
        
        guard let aiManager = state.aiManager else {
            fatalErrorIfDebug("handleErrorWhenApplyingChunk: no ai manager")
            // TODO: show error modal to user?
            return
        }
        
        let retryRequest = { (aiManager: StitchAIManager) in
            aiManager.currentTask?.cancel()
            aiManager.currentTask = nil
            aiManager.currentTask = aiManager.getOpenAIStreamingTask(
                request: request,
                attempt: currentAttempt + 1,
                document: state)
        }
        
        // TODO: get rid of this?
        state.visibleGraph.streamedSteps.append(newStep)
        
//         log("ChunkProcessed: state.visibleGraph.streamedSteps is now: \(state.visibleGraph.streamedSteps)")

        // If we coould
        let parsingError = newStep.convertToType()
        
//        state.llmRecording.actions = Array(state.visibleGraph.streamedSteps)
        log("ChunkProcessed: state.llmRecording.actions is now: \(state.llmRecording.actions)")
        
        // When we receive a new step, we may 
                
        if let error = state.reapplyActionsDuringEditMode(steps: state.llmRecording.actions) {
            log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: error: \(error) for request.prompt: \(request.prompt)")
            
            
            // Completely cancel the current task and create a new one
            
        } else {
            log("ChunkProcessed: SUCCESSFULLY REAPPLIED LLM ACTIONS")
        }
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleErrorWhenMakingOpenAIStreamingRequest(_ error: Error, _ request: OpenAIRequest) {
        
        let document = self
        
        // Reset recording state
        document.llmRecording = .init()

        // TODO: comment below is slightly obscure -- what's going on here?
        // Reset checks which would later break new recording mode
        document.insertNodeMenuState = InsertNodeMenuState()
        
        if let error = error as? StitchAIManagerError,
           error.shouldDisplayModal {
            
            document.showErrorModal(
                message: error.description,
                userPrompt: request.prompt
            )
        } else {
            document.showErrorModal(
                message: "StitchAI handleRequest unknown error: \(error)",
                userPrompt: request.prompt
            )
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor func handleStitchAIError(_ error: Error) {
        log("Error generating graph with StitchAI: \(error)", .logToServer)
        self.insertNodeMenuState.show = false
        self.insertNodeMenuState.isGeneratingAIResult = false
    }
}
