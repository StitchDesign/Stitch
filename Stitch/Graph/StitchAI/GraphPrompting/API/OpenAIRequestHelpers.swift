//
//  OpenAIRequestHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/7/25.
//

import Foundation

extension StitchAIManager {
    
    // Either successfully retries -- or shows error modal for a non-retryable error
    @MainActor
    func retryOrShowErrorModal(request: OpenAIRequest,
                               attempt: Int,
                               lastCapturedError: String = "last error from retryRequest",
                               document: StitchDocumentViewModel) async {
        
        if let retryError = await _retryRequest(request: request, attempt: attempt, document: document),
           // If, while attempting a retry, we encounter an non-retry-able error (e.g. max timeouts or max retries),
           // we show an error modal to the user.
           !retryError.shouldRetryRequest {
            
            // Always make sure we're on main thread
            // TODO: do we really need to do this, in a function marked as @MainActor ?
            await MainActor.run { [weak document] in
                guard let document = document else {
                    fatalErrorIfDebug()
                    return
                }
                document.handleNonRetryableError(retryError, request)
            }
        }
    }
    
    // TODO: we attempt the request again when OpenAI has sent us data that either could not be parsed or could not be validated; should we also re-attempt when OpenAI gives us a timeout error?
    @MainActor
    private func _retryRequest(request: OpenAIRequest,
                               attempt: Int,
                               lastCapturedError: String = "last error from retryRequest",
                               document: StitchDocumentViewModel) async -> StitchAIStreamingError? {
        
        log("StitchAIManager: retryRequest called")
        
        if document.llmRecording.currentlyInARetryDelay {
            log("StitchAIManager: retryRequest: currently in a retry delay; not re-attempting")
            return .currentlyInARetryDelay
        } else {
            document.llmRecording.currentlyInARetryDelay = true
        }
        
        if attempt > request.config.maxRetries {
            log("All StitchAI retry attempts exhausted", .logToServer)
            return .maxRetriesError(request.config.maxRetries,
                                    lastCapturedError)
        }
        
        
        let aiManager = self
        
        // Immediately cancel the current task
        aiManager.currentTask?.task.cancel()
        aiManager.currentTask = nil
        
        // Before starting a new task, remove the effects of the existing actions
        document.deapplyActions(actions: document.llmRecording.actions)

        // Then wipe the received steps and existing actions
        document.llmRecording.streamedSteps = .init()
        document.llmRecording.actions = .init()
        
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
        
        document.llmRecording.currentlyInARetryDelay = false
        
        return nil
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
                
        // Helpful for debug to keep around the streamed-in Steps while a given task is active
        state.llmRecording.streamedSteps.append(newStep)
            
        // Parsing the Step is not async, but retry-on-failure *is*, since we wait some small delay.
        let parseAttempt: Result<any StepActionable, StitchAIStepHandlingError> = newStep.parseAsStepAction()
        
        Task(priority: .high) { [weak aiManager] in
            
            guard let aiManager = aiManager,
                  var nodeIdMap = aiManager.currentTask?.nodeIdMap else {
                log("Did not have AI manager and/or current task")
                return
            }
            
            switch parseAttempt {
                
            case .failure(let parsingError):
                log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: parsingError: \(parsingError) for request.prompt: \(request.prompt)")
                if parsingError.shouldRetryRequest {
                    await aiManager.retryOrShowErrorModal(
                        request: request,
                        attempt: currentAttempt,
                        document: state)
                }
                
            case .success(var parsedStep):
                log("ChunkProcessed: successfully parsed step, parsedStep: \(parsedStep)")
                
//                // Note: OpenAI can apparently send us the same UUIDs across completely different requests. So, we never actually use the `Step.nodeId: StitchAIUUID`; instead, we create a new, guaranteed-always-unique NodeId and update the parsed steps as they come in.
//                // TODO: update the system prompt to force OpenAI to send genuinely unique UUIDs everytime
                if newStep.stepType.introducesNewNode,
                   let newStepNodeId: StitchAIUUID = newStep.nodeId {
                    log("ChunkProcessed: nodeIdMap was: \(nodeIdMap)")
                    nodeIdMap.updateValue(
                        // a new, ALWAYS unique Stitch node id
                        NodeId(),
                        // the node id OpenAI sent us, may be repeated across requests
                        forKey: newStepNodeId
                    )
                    
                    // Update the current task's stored node id map
                    aiManager.currentTask?.nodeIdMap = nodeIdMap
                    log("ChunkProcessed: nodeIdMap is now: \(nodeIdMap)")
                }
                
                log("ChunkProcessed: parsedStep was: \(parsedStep)")
                parsedStep = parsedStep.remapNodeIds(nodeIdMap: nodeIdMap)
                log("ChunkProcessed: parsedStep is now: \(parsedStep)")
                
                if let validationError = state.onNewStepReceived(originalSteps: state.llmRecording.actions,
                                                                 newStep: parsedStep) {
                    log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: validationError: \(validationError) for request.prompt: \(request.prompt)")
                    if validationError.shouldRetryRequest {
                        await aiManager.retryOrShowErrorModal(
                            request: request,
                            attempt: currentAttempt,
                            document: state)
                    }
                } else {
                    log("ChunkProcessed: SUCCESSFULLY APPLIED NEW STEP")
                }
            }
        } // Task
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleNonRetryableError(_ error: StitchAIStreamingError,
                                 _ request: OpenAIRequest) {
        
        log("handleNonRetryableError: will not retry request")
        
        // Reset recording state
        self.llmRecording = .init()
        
        // TODO: comment below is slightly obscure -- what's going on here?
        // Reset checks which would later break new recording mode
        self.insertNodeMenuState = InsertNodeMenuState()
        
        // TODO: should also wipe the currentTask ?
        self.aiManager?.currentTask?.task.cancel()
        self.aiManager?.currentTask = nil
        
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
