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
        
        let recreateTask = { (_ aiManager: StitchAIManager) in
            aiManager.currentTask?.cancel()
            aiManager.currentTask = nil
            aiManager.currentTask = aiManager.getOpenAIStreamingTask(
                request: request,
                attempt: currentAttempt + 1,
                document: state)
        }
        
        // TODO: get rid of this? or keep around for helpful debug?
        state.visibleGraph.streamedSteps.append(newStep)

        // If we coould
        switch newStep.convertToType() {
        case .failure(let error):
            log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: error: \(error) for request.prompt: \(request.prompt)")
            recreateTask(aiManager)
            
        case .success(let parsedStep):
            log("ChunkProcessed: successfully parsed step, parsedStep: \(parsedStep)")
            if let validationError = state.onNewStepReceived(originalSteps: state.llmRecording.actions,
                                                             newStep: parsedStep) {
                log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: validationError: \(validationError) for request.prompt: \(request.prompt)")
                recreateTask(aiManager)
            } else {
                log("ChunkProcessed: SUCCESSFULLY APPLIED NEW STEP")
            }
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
