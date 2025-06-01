//
//  OpenAIRetryRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/27/25.
//

import Foundation


extension StitchAIManager {
    
    // Either successfully retries -- or shows error modal for a non-retryable error
    @MainActor
    func retryOrShowErrorModal<AIRequest>(request: AIRequest,
                                          steps: Steps,
                                          attempt: Int,
                                          document: StitchDocumentViewModel,
                                          canShareAIRetries: Bool) async where AIRequest: StitchAIRequestable {
        
        log("StitchAIManager: retryOrShowErrorModal called: attempt: \(attempt), request.prompt: \(request.userPrompt)")
        
        if let retryError = await _retryRequest(request: request,
                                                steps: steps,
                                                attempt: attempt,
                                                document: document,
                                                canShareAIRetries: canShareAIRetries),
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
    private func _retryRequest<AIRequest>(request: AIRequest,
                                          steps: Steps,
                                          attempt: Int,
                                          document: StitchDocumentViewModel,
                                          canShareAIRetries: Bool) async -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        log("StitchAIManager: _retryRequest called: attempt: \(attempt)")
        
        // While in a retry delay, we do not want to retry again.
        if document.llmRecording.currentlyInARetryDelay {
            log("StitchAIManager: _retryRequest: currently in a retry delay; not re-attempting")
            return .currentlyInARetryDelay
        } else {
            document.llmRecording.currentlyInARetryDelay = true
        }
        
        if attempt > request.config.maxRetries {
            log("_retryRequest: All StitchAI retry attempts exhausted", .logToServer)
            return .maxRetriesError(request.config.maxRetries,
                                    document.llmRecording.actionsError ?? "")
        }
        
        
        
        if canShareAIRetries {
            Task(priority: .high) { [weak self] in
                guard let aiManager = self,
                      let deviceUUID = StitchAIManager.getDeviceUUID() else {
                    log("_retryRequest error: no AI Manager or no device ID found.")
                    return
                }
                
                do {
                    try await aiManager.uploadActionsToSupabase(
                        prompt: request.userPrompt,
                        // Send the raw-streamed steps
                        finalActions: Array(document.llmRecording.streamedSteps),
                        deviceUUID: deviceUUID,
                        isCorrection: false,
                        rating: .oneStar,
                        // These actions could not be parsed and/or validated, so
                        requiredRetry: true)
                } catch  {
                    log("_retryRequest: had error when trying to share retry: \(error)", .logToServer)
                }
                
            }
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
        log("_retryRequest: Retrying request with backoff delay: \(cappedDelay) seconds")
        let slept: ()? = try? await Task.sleep(nanoseconds: UInt64(cappedDelay * Double(nanoSecondsInSecond)))
        
        // This can somehow fail?
        // assertInDebug(slept.isDefined)
            
        let task = aiManager.getOpenAITask(
            request: request,
            attempt: attempt + 1,
            document: document,
            canShareAIRetries: canShareAIRetries)
        
        aiManager.currentTask = .init(
            task: task,
            // Will be populated as each chunk is processed
            nodeIdMap: .init())
        
        document.llmRecording.currentlyInARetryDelay = false
        
        return nil
    }
}


extension StitchDocumentViewModel {
    
    @MainActor
    func handleNonRetryableError<AIRequest>(_ error: StitchAIStreamingError,
                                            _ request: AIRequest) where AIRequest: StitchAIRequestable {
        
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
                            userPrompt: request.userPrompt)
    }
}
