//
//  OpenAIRequest.swift
//  Core implementation for making requests to OpenAI's API with retry logic and error handling.
//  This file handles API communication, response parsing, and state management for the Stitch app.
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation
@preconcurrency import SwiftyJSON
import SwiftUI
import Sentry
import SwiftyJSON

extension StitchAIManager {
    
    // Used when we need to kick off a request, either initially or as a retry
    @MainActor
    func getOpenAITask(request: AIGraphCreationRequest,
                       attempt: Int,
                       document: StitchDocumentViewModel,
                       canShareAIRetries: Bool) -> Task<OpenAIMessage, any Error> {
        Task(priority: .high) { [weak self] in
            guard let aiManager = self else {
                fatalErrorIfDebug()
                throw NSError()
            }
            
            switch await aiManager.startOpenAIRequest(
                request,
                attempt: attempt,
                lastCapturedError: document.llmRecording.actionsError ?? "",
                document: document) {
                
            case .success(let result):
                log("getOpenAIStreamingTask: succeeded")
                
                // Handle successful response
                // Note: does not fire until we properly handle the whole request
                await MainActor.run { [weak document] in
                    guard let document = document else {
                        fatalErrorIfDebug("getOpenAIStreamingTask: no document")
                        return
                    }
                    aiManager.aiGraphRequestCompleted(request: request,
                                                      document: document)
                }
                
                return result
                
            case .failure(let error):
                log("getOpenAIStreamingTask: error: \(error.description)")
                
                // If the error was a timeout or rate limit, we'll want to try again:
                if error.shouldRetryRequest {
                    await aiManager.retryOrShowErrorModal(
                        request: request,
                        steps: Array(document.llmRecording.streamedSteps),
                        attempt: attempt,
                        document: document,
                        canShareAIRetries: canShareAIRetries)
                }
                
                // Else, if e.g. 'no internet connection', we won't try again and will show error modal to the user.
                else {
                    // TODO: do we really need to do this on `MainActor.run`? See also note in `retryOrShowErrorModal`
                    await MainActor.run { [weak document] in
                        guard let document = document else {
                            fatalErrorIfDebug("getOpenAIStreamingTask: no document")
                            document?.aiManager?.cancelCurrentRequest()
                            return
                        }
                        document.handleNonRetryableError(error, request)
                    }
                }
                
                throw error
            }
        }
    }
        
    // Note: the failures that can happen in here are catastrophic and meant for us as developers, not something the user can take action on
    static func getURLRequestForOpenAI<AIRequest>(request: AIRequest,
                                                  secrets: Secrets) -> URLRequest? where AIRequest: StitchAIRequestable {
        
        let config = request.config
                
        // Configure request headers and parameters
        var urlRequest = URLRequest(url: OPEN_AI_BASE_URL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        let bodyPayload = try? request.getPayloadData()
        urlRequest.httpBody = bodyPayload
        
        return urlRequest
    }
    
    /// Execute the API request with retry logic
    // fka `makeRequest`
    func startOpenAIRequest<AIRequest>(_ request: AIRequest,
                                       attempt: Int,
                                       lastCapturedError: String,
                                       document: StitchDocumentViewModel) async -> Result<OpenAIMessage, StitchAIStreamingError> where AIRequest: StitchAIRequestable {
        
        // Check if we've exceeded retry attempts
        guard attempt <= request.config.maxRetries else {
            log("All StitchAI retry attempts exhausted", .logToServer)
            return .failure(.maxRetriesError(request.config.maxRetries,
                                             lastCapturedError))
        }
        
        guard let urlRequest = Self.getURLRequestForOpenAI(request: request,
                                                           secrets: self.secrets) else {
            log("StitchAIManager: startOpenAIRequest: could not get request", .logToServer)
            return .failure(.urlRequestCreationFailure)
        }
        
        let streamOpeningResult = await self.makeRequest(
            for: urlRequest,
            with: request,
            attempt: attempt,
            document: document)
        
        switch streamOpeningResult {
            
        case .success(let response):
            // Even if we had a successful response, may have hit a rate limit?
            // TODO: is this still necessary for streaming requests?
            if let error = handlePossibleRateLimit(
                response: response.1,
                request: request) {
                return .failure(error)
            }
            
            return .success(response.0)
            
        case .failure(let error):
            // Note: `error` might be a cancellation, which is acceptable and not an error
            log("StitchAIManager: startOpenAIRequest: streaming error: \(error.localizedDescription)", .logToServer)
            if let error = handleOpenAIStreamingError(
                error,
                attempt: attempt,
                request: request) {
                return .failure(error)
            }
            
            return .failure(.other(error))
        }
    }
     
    private func handlePossibleRateLimit<AIRequest>(response: URLResponse,
                                                    request: AIRequest) -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            // Retry on rate limit or server errors
            if httpResponse.statusCode == 429 || // Rate limit
                httpResponse.statusCode >= 500 {  // Server error
                log("StitchAI Request failed with status code: \(httpResponse.statusCode)", .logToServer)
                log("Retrying in \(request.config.retryDelay) seconds")
                
                return .rateLimit
            }
        }
        
        // else no error, we're all good!
        return nil
    }
    
    // An error that occurred when we attempted to open the stream, or as the stream was open
    // Note: NOT the same as an error when validating or applying parsed Steps; for that, see `handleErrorWhenApplyingChunk`
    private func handleOpenAIStreamingError<AIRequest>(_ error: Error,
                                                       attempt: Int,
                                                       request: AIRequest) -> StitchAIStreamingError? where AIRequest: StitchAIRequestable {
        
        log("OpenAI request failed: \(error)")
        
        if let _ = (error as? CancellationError) {
            return nil // Cancellation is not an error
        }
        
        guard let error = error as NSError? else {
            // If we don't have an NSError, treat error as invalid url ?
            return .invalidURL
        }
        
        // Handle network errors
        
        // Don't show error for cancelled requests
        if error.code == NSURLErrorCancelled {
            // return .requestCancelled
            return nil // Cancellation is not an error
        }
        
        // Handle timeout errors
        else if error.code == NSURLErrorTimedOut {
            log("Timeout error count: \(attempt)")
            
            if attempt > request.config.maxTimeoutErrors {
                return .maxTimeouts //.multipleTimeoutErrors(request, error.localizedDescription)
            } else {
                return .timeout //.timeout(request, error.localizedDescription)
            }
        }
        
        // Handle network connection errors
       else if error.code == NSURLErrorNotConnectedToInternet ||
            error.code == NSURLErrorNetworkConnectionLost {
            return .internetConnectionFailed
        }
        
        // Handle other errors
        else {
            return .other(error)
        }
    }
    

    // Note: this actually fires WHENEVER the stream is closed, e.g. even when task is cancelled
    
    // We successfully opened the stream and received bits until the stream was closed (without an error?).
    // fka `openAIRequestCompleted`
    @MainActor
    func aiGraphRequestCompleted(request: AIGraphCreationRequest,
                                 document: StitchDocumentViewModel) {
        log("openAIStreamingCompleted called")
        
        document.reduxFocusedField = nil
        
        // Set auto-hiding flag before hiding menu
        document.insertNodeMenuState.isAutoHiding = true
        
        document.insertNodeMenuState.show = false
        document.aiManager?.cancelCurrentRequest()
        
        log("Storing user prompt and request id")
        document.llmRecording.promptForTrainingDataOrCompletedRequest = request.userPrompt
        document.llmRecording.requestIdFromCompletedRequest = request.id
        
        // Only ask for rating if we received some actions
        if !document.llmRecording.streamedSteps.isEmpty {
            document.llmRecording.modal = .ratingToast(userInputPrompt: request.userPrompt)
        }
                
        document.encodeProjectInBackground()
    }
}

extension StitchAIRequestable {
    func request(document: StitchDocumentViewModel,
                 aiManager: StitchAIManager) async throws -> Self.FinalDecodedResult {
        let result = await aiManager.startOpenAIRequest(self,
                                                        attempt: 0,
                                                        lastCapturedError: "",
                                                        document: document)
        
        switch result {
            
        case .success(let msg):
            log("StitchAIRequestable: requestForMessage: success")
            let initialDecodedResult = try Self.parseOpenAIResponse(message: msg)
            let result = try Self.validateResponse(decodedResult: initialDecodedResult)
            return result

        case .failure(let failure):
            log("StitchAIRequestable: requestForMessage: failure")
            logToServerIfRelease("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
            throw failure
        }
    }
}

extension StitchAIFunctionRequestable {
    func requestForFnMessage(functionType: StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction,
                             requestType: StitchAIRequestBuilder_V0.StitchAIRequestType,
                             document: StitchDocumentViewModel,
                             aiManager: StitchAIManager) async throws -> OpenAIMessage {
        let result = await aiManager.startOpenAIRequest(self,
                                                        attempt: 0,
                                                        lastCapturedError: "",
                                                        document: document)
        
        switch result {
            
        case .success(var msg):
            log("StitchAIRequestable: requestForMessage: success")
            
            // Update message with assistant prompt
            msg.content = try functionType.getAssistantPrompt(for: requestType)
            
            return msg
        case .failure(let failure):
            log("StitchAIRequestable: requestForMessage: failure")
            logToServerIfRelease("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
            throw failure
        }
    }
}
