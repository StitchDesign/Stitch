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
