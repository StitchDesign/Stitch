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
struct OpenAIRequest {
    private let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    let prompt: String             // User's input prompt
    let systemPrompt: String       // System-level instructions loaded from file
    let config: OpenAIRequestConfig // Request configuration settings
    
    /// Initialize a new request with prompt and optional configuration
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default,
         systemPrompt: String) {
        self.prompt = prompt
        self.config = config
        self.systemPrompt = systemPrompt
    }
}

extension StitchAIManager {
   
    // Used when we need to kick off a request, either initially or as a retry
    @MainActor
    func getOpenAIStreamingTask(request: OpenAIRequest,
                                attempt: Int,
                                document: StitchDocumentViewModel) -> Task<Void, Never>? {
        
        Task(priority: .high) { [weak self] in
            
            guard let aiManager = self else {
                log("getOpenAIStreamingTask: no aiManager")
                return
            }
            
            do {
                try await aiManager.makeOpenAIStreamingRequest(
                    request,
                    attempt: attempt,
                    document: document)
                
                log("OpenAI Request succeeded")
                
                // Handle successful response
                // Note: does not fire until we properly handle the whole request
                try aiManager.openAIStreamingCompleted(
                    originalPrompt: request.prompt,
                    document: document)
            } // do
            
            catch {
                log("StitchAI handleRequest error: \(error.localizedDescription)", .logToServer)
                
                await MainActor.run { [weak document] in
                    guard let document = document else {
                        log("getOpenAIStreamingTask: no document")
                        return
                    }
                    
                    document.handleErrorWhenMakingOpenAIStreamingRequest(error, request)
                }
            } // catch
         
            // Whether we succeeded or failed,
            // reset "is generating AI node" on the node menu.
            await MainActor.run { [weak document] in
                document?.insertNodeMenuState.isGeneratingAIResult = false
            }
            
        }
    }
        
    // Note: the failures that can happen in here are catastrophic and meant for us as developers, not something the user can take action on
    @MainActor
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
    @MainActor
    func makeOpenAIStreamingRequest(_ request: OpenAIRequest,
                                    attempt: Int, // = 1,
                                    lastCapturedError: String? = nil,
                                    document: StitchDocumentViewModel) async -> StitchAIManagerError? {
                        
        // Check if we've exceeded retry attempts
        guard attempt <= request.config.maxRetries else {
            log("All StitchAI retry attempts exhausted", .logToServer)
            return StitchAIManagerError.maxRetriesError(request.config.maxRetries,
                                                       lastCapturedError ?? "")
        }
        
        guard let urlRequest = Self.getURLRequestForOpenAI(request: request,
                                                           secrets: self.secrets) else {
            fatalErrorIfDebug()
            return nil
        }
        
        let streamOpeningResult = await self.startOpenAIStreamingRequest(
            for: urlRequest,
            with: request,
            attempt: attempt)
        
        switch streamOpeningResult {
        
        case .success(let response):
            // Even if we had a successful response, may have hit a rate limit?
            // TODO: is this still necessary for streaming requests?
            return await handlePossibleRateLimit(
                response: response,
                request: request,
                attempt: attempt,
                document: document)
            
        case .failure(let error):
            return await self.handleOpenAIStreamingError(
                error,
                attempt: attempt,
                request: request,
                document: document)
        }
    }
     
    func handlePossibleRateLimit(response: URLResponse,
                                 request: OpenAIRequest,
                                 attempt: Int,
                                 document: StitchDocumentViewModel) async -> StitchAIManagerError? {
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            // Retry on rate limit or server errors
            if httpResponse.statusCode == 429 || // Rate limit
                httpResponse.statusCode >= 500 {  // Server error
                log("StitchAI Request failed with status code: \(httpResponse.statusCode)", .logToServer)
                log("Retrying in \(request.config.retryDelay) seconds")
                return await self.retryMakeOpenAIStreamingRequest(request,
                                                                  currentAttempts: attempt + 1,
                                                                  lastError: StitchAIManagerError.apiResponseError.description,
                                                                  document: document)
            }
        }
        
        // else no error, we're all good!
        return nil
    }
    
    // An error that occurred when we attempted to open the stream, or as the stream was open
    // Note: NOT the same as an error when validating or applying parsed Steps; for that, see `handleErrorWhenApplyingChunk`
    func handleOpenAIStreamingError(_ error: Error,
                                    attempt: Int,
                                    request: OpenAIRequest,
                                    document: StitchDocumentViewModel) async -> StitchAIManagerError? {
        
        log("OpenAI request failed: \(error)")
        
        guard let error = error as NSError? else {
            // If we don't have an NSError, treat error as invalid url ?
            return StitchAIManagerError.invalidURL(request)
        }
        
        // Handle network errors
        
        // Don't show error for cancelled requests
        if error.code == NSURLErrorCancelled {
            return StitchAIManagerError.requestCancelled(request)
        }
        
        // Handle timeout errors
        else if error.code == NSURLErrorTimedOut {
            log("Timeout error count: \(attempt)")
            
            if attempt > request.config.maxTimeoutErrors {
                return StitchAIManagerError.multipleTimeoutErrors(request, error.localizedDescription)
            }
            
            log("StitchAI Request timed out: \(error.localizedDescription)", .logToServer)
            log("Retrying in \(request.config.retryDelay) seconds")
            
            return await self.retryMakeOpenAIStreamingRequest(
                request,
                currentAttempts: attempt + 1,
                lastError: error.localizedDescription,
                document: document)
        }
        
        // Handle network connection errors
       else if error.code == NSURLErrorNotConnectedToInternet ||
            error.code == NSURLErrorNetworkConnectionLost {
            return StitchAIManagerError.internetConnectionFailed(request)
        }
        
        // Handle other errors
        else {
            return StitchAIManagerError.other(request, error)
        }
    }
    
    func retryMakeOpenAIStreamingRequest(_ request: OpenAIRequest,
                                         currentAttempts: Int,
                                         lastError: String,
                                         document: StitchDocumentViewModel) async -> StitchAIManagerError? {

        // Calculate exponential backoff delay: 2^attempt * base delay
        let backoffDelay = pow(2.0, Double(currentAttempts)) * request.config.retryDelay
        // Cap the maximum delay at 30 seconds
        let cappedDelay = min(backoffDelay, 30.0)
        
        // TODO: can `Task.sleep` really "fail" ?
        log("Retrying request with backoff delay: \(cappedDelay) seconds")
        let slept: ()? = try? await Task.sleep(nanoseconds: UInt64(cappedDelay * Double(nanoSecondsInSecond)))
        assertInDebug(slept.isDefined)
        
        return await self.makeOpenAIStreamingRequest(request,
                                                     attempt: currentAttempts + 1,
                                                     lastCapturedError: lastError,
                                                     document: document)
    }
    
    // We successfully opened the stream and received bits until the stream was closed (without an error?).
    // fka `openAIRequestCompleted`
    @MainActor
    func openAIStreamingCompleted(originalPrompt: String,
                                  document: StitchDocumentViewModel) throws {
        log("openAIStreamingCompleted called")
        
        document.reduxFocusedField = nil
        
        // Set auto-hiding flag before hiding menu
        document.insertNodeMenuState.isAutoHiding = true
        
         document.insertNodeMenuState.show = false
         document.insertNodeMenuState.isGeneratingAIResult = false

        log(" Storing Original AI Generated Actions ")
        document.llmRecording.promptState.prompt = originalPrompt
        
        // Enable edit mode for actions after successful request
//        document.llmRecording.mode = .augmentation
        document.llmRecording.mode = .normal
        
        document.encodeProjectInBackground()
    }
}
