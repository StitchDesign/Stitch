//
//  OpenAIRequestHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/7/25.
//

import Foundation

extension StitchAIManager {
    
    @MainActor
    func maybeRetryOnError(request: OpenAIRequest,
                           errorFromOpeningStream: StitchAIStreamingError?,
                           errorFromValidation: StitchAIStepHandlingError?,
                           attempt: Int,
                           document: StitchDocumentViewModel) async {
        
        let shouldRetry = errorFromOpeningStream?.shouldRetryRequest ?? errorFromValidation?.shouldRetryRequest ?? false
        
        if shouldRetry {
            await self.retryRequest(request: request, attempt: attempt, document: document)
        } else {
            log("Will not retry request, had errorFromOpeningStream: \(errorFromOpeningStream?.description) and errorFromValidation \(errorFromValidation?.description)")
        }
    }
    
    // TODO: we attempt the request again when OpenAI has sent us data that either could not be parsed or could not be validated; should we also re-attempt when OpenAI gives us a timeout error?
    @MainActor
    func retryRequest(request: OpenAIRequest,
                      attempt: Int,
                      document: StitchDocumentViewModel) async {
        
        log("StitchAIManager: retryRequest called")
        
        let aiManager = self
        
        // Immediately cancel the current task
        aiManager.currentTask?.task.cancel()
        aiManager.currentTask = nil
        
        // Calculate an exponential backoff delay and then re-attempt the task
        // Calculate exponential backoff delay: 2^attempt * base delay
        let backoffDelay = pow(2.0, Double(attempt)) * request.config.retryDelay
        // Cap the maximum delay at 30 seconds
        let cappedDelay = min(backoffDelay, 30.0)
        
        // TODO: can `Task.sleep` really "fail" ?
        log("Retrying request with backoff delay: \(cappedDelay) seconds")
        let slept: ()? = try? await Task.sleep(nanoseconds: UInt64(cappedDelay * Double(nanoSecondsInSecond)))
        assertInDebug(slept.isDefined)
                
        let task = aiManager.getOpenAIStreamingTask(
            request: request,
            attempt: attempt + 1,
            document: document)
        
        aiManager.currentTask = .init(
            task: task,
            // Will be populated as each chunk is processed
            nodeIdMap: .init())
    }
}

struct ChunkProcessed: StitchDocumentEvent {
    let newStep: Step
    let request: OpenAIRequest
    let currentAttempt: Int
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        log("ChunkProcessed: newStep: \(newStep)")
        
        guard let aiManager = state.aiManager else {
            fatalErrorIfDebug("handleErrorWhenApplyingChunk: no ai manager")
            // TODO: show error modal to user?
            return
        }
                
        // TODO: get rid of this? or keep around for helpful debug?
        state.visibleGraph.streamedSteps.append(newStep)

        // Parsing the Step is not async, but retry-on-failure *is*, since we wait some small delay.
        // Note also: recreating the task needs to be done on the main thread, since the current task lives on the main thread.
        let parseAttempt: Result<any StepActionable, StitchAIStepHandlingError> = newStep.convertToType()
        
        Task(priority: .high) { [weak aiManager] in
            
            guard let aiManager = aiManager else {
                log("Did not have AI manager")
                return
            }
            
            // Would this closure retain (= memory leak) the AI-manager ?
            //            let handleError = { (error: StitchAIStepHandlingError) in
            //                await aiManager.maybeRetryOnError(request: request,
            //                                            errorFromOpeningStream: nil,
            //                                            errorFromValidation: error,
            //                                            attempt: currentAttempt,
            //                                            document: state)
            //            }
            
            switch parseAttempt {
                
            case .failure(let error):
                log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: error: \(error) for request.prompt: \(request.prompt)")
                await aiManager.maybeRetryOnError(request: request,
                                                  errorFromOpeningStream: nil,
                                                  errorFromValidation: error,
                                                  attempt: currentAttempt,
                                                  document: state)
                
            case .success(let parsedStep):
                log("ChunkProcessed: successfully parsed step, parsedStep: \(parsedStep)")
                if let validationError = state.onNewStepReceived(originalSteps: state.llmRecording.actions,
                                                                 newStep: parsedStep) {
                    log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: validationError: \(validationError) for request.prompt: \(request.prompt)")
                    await aiManager.maybeRetryOnError(request: request,
                                                      errorFromOpeningStream: nil,
                                                      errorFromValidation: validationError,
                                                      attempt: currentAttempt,
                                                      document: state)
                } else {
                    log("ChunkProcessed: SUCCESSFULLY APPLIED NEW STEP")
                }
            }
        } // Task
    }
}



extension StitchDocumentViewModel {
    
    @MainActor
    func handleNonRetryableError(_ error: StitchAIStreamingError, _ request: OpenAIRequest) {
        log("handleNonRetryableError: will not retry request")
        
        // Reset recording state
        self.llmRecording = .init()
        
        // TODO: comment below is slightly obscure -- what's going on here?
        // Reset checks which would later break new recording mode
        self.insertNodeMenuState = InsertNodeMenuState()
        
        self.showErrorModal(message: error.description,
                            userPrompt: request.prompt)
    }
}

extension StitchDocumentViewModel {
    @MainActor func handleStitchAIError(_ error: Error) {
        log("Error generating graph with StitchAI: \(error)", .logToServer)
        self.insertNodeMenuState.show = false
        self.insertNodeMenuState.isGeneratingAIResult = false
    }
}
