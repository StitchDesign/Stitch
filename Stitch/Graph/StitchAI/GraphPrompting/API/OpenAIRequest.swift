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

// If this is not a valid URL, we should not even be able to run the app.
let OPEN_AI_BASE_URL_STRING = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_BASE_URL: URL = URL(string: OPEN_AI_BASE_URL_STRING)!

// Note: an event is usually not a long-lived data structure; but this is used for retry attempts.
/// Main event handler for initiating OpenAI API requests
struct OpenAIRequest: Equatable, Hashable {
    private let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    let prompt: UserAIPrompt             // User's input prompt
    let systemPrompt: String       // System-level instructions loaded from file
    let config: OpenAIRequestConfig // Request configuration settings
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default,
         systemPrompt: String) {
        self.prompt = .init(prompt)
        self.config = config
        self.systemPrompt = systemPrompt
    }
}

extension StitchAIManager {
    
    // Used when we need to kick off a request, either initially or as a retry
    @MainActor
    func getOpenAIStreamingTask(request: OpenAIRequest,
                                attempt: Int,
                                document: StitchDocumentViewModel,
                                canShareAIRetries: Bool) -> Task<Void, Never> {
        
        Task(priority: .high) { [weak self] in
            
            guard let aiManager = self else {
                log("getOpenAIStreamingTask: no aiManager")
                return
            }
            
            switch await aiManager.startOpenAIStreamingRequest(
                request,
                attempt: attempt,
                lastCapturedError: document.llmRecording.actionsError ?? "") {
            
            case .none: // No error!
                log("getOpenAIStreamingTask: succeeded")
                
                // Handle successful response
                // Note: does not fire until we properly handle the whole request
                await MainActor.run { [weak document] in
                    guard let document = document else {
                        fatalErrorIfDebug("getOpenAIStreamingTask: no document")
                        return
                    }
                    aiManager.openAIStreamingCompleted(originalPrompt: request.prompt,
                                                       request: request,
                                                       document: document)
                }
                
            case .some(let error):
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
                            return
                        }
                        document.handleNonRetryableError(error, request)
                    }
                }
            }
            
            // Whether we succeeded or failed,
            // reset "is generating AI node" on the node menu.
            await MainActor.run { [weak document] in
                document?.insertNodeMenuState.isGeneratingAIResult = false
            }
        }
    }
        
    // Note: the failures that can happen in here are catastrophic and meant for us as developers, not something the user can take action on
    static func getURLRequestForOpenAI(request: OpenAIRequest,
                                       secrets: Secrets) -> URLRequest? {
        
        let config = request.config
        let prompt = request.prompt
        let systemPrompt = request.systemPrompt
                
        // Configure request headers and parameters
        var urlRequest = URLRequest(url: OPEN_AI_BASE_URL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        let payload = StitchAIRequest(secrets: secrets,
                                      userPrompt: prompt,
                                      systemPrompt: systemPrompt)
        
        let encoder = JSONEncoder()
        // encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let jsonData = try? encoder.encode(payload) else {
            fatalErrorIfDebug("Could not encode payload")
            return nil
        }
        
        urlRequest.httpBody = jsonData
        return urlRequest
    }
    
    /// Execute the API request with retry logic
    // fka `makeRequest`
    func startOpenAIStreamingRequest(_ request: OpenAIRequest,
                                     attempt: Int,
                                     lastCapturedError: String) async -> StitchAIStreamingError? {
        
        // Check if we've exceeded retry attempts
        guard attempt <= request.config.maxRetries else {
            log("All StitchAI retry attempts exhausted", .logToServer)
            return .maxRetriesError(request.config.maxRetries,
                                    lastCapturedError)
        }
        
        guard let urlRequest = Self.getURLRequestForOpenAI(request: request,
                                                           secrets: self.secrets) else {
            fatalErrorIfDebug()
            return nil
        }
        
        let streamOpeningResult = await self.openStream(
            for: urlRequest,
            with: request,
            attempt: attempt)
        
        switch streamOpeningResult {
            
        case .success(let response):
            // Even if we had a successful response, may have hit a rate limit?
            // TODO: is this still necessary for streaming requests?
            return handlePossibleRateLimit(
                response: response,
                request: request)
            
        case .failure(let error):
            // Note: `error` might be a cancellation, which is acceptable and not an error
            return handleOpenAIStreamingError(
                error,
                attempt: attempt,
                request: request)
        }
    }
     
    private func handlePossibleRateLimit(response: URLResponse,
                                 request: OpenAIRequest) -> StitchAIStreamingError? {
        
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
    private func handleOpenAIStreamingError(_ error: Error,
                                    attempt: Int,
                                    request: OpenAIRequest) -> StitchAIStreamingError? {
        
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
    func openAIStreamingCompleted(originalPrompt: UserAIPrompt,
                                  request: OpenAIRequest,
                                  document: StitchDocumentViewModel) {
        log("openAIStreamingCompleted called")
        
        document.reduxFocusedField = nil
        
        // Set auto-hiding flag before hiding menu
        document.insertNodeMenuState.isAutoHiding = true
        
         document.insertNodeMenuState.show = false
         document.insertNodeMenuState.isGeneratingAIResult = false

        log(" Storing Original AI Generated Actions ")
        document.llmRecording.promptForTrainingDataOrCompletedRequest = originalPrompt
        
        // Enable edit mode for actions after successful request
//        document.llmRecording.mode = .augmentation
        document.llmRecording.mode = .normal
        
        // Only ask for rating if we received some actions
        if !document.llmRecording.streamedSteps.isEmpty {
            document.llmRecording.modal = .ratingToast(userInputPrompt: request.prompt)
        }
        
                
        document.encodeProjectInBackground()
    }
}
