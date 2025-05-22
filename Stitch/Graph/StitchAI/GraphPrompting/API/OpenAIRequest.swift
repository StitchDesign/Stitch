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

let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"

extension StitchAIManager {
        
    @MainActor
    func handleRequest(_ request: OpenAIRequest,
                       document: StitchDocumentViewModel) {

        // Set the flag to indicate a request is in progress
        withAnimation {
            document.insertNodeMenuState.isGeneratingAIResult = true
        }
        
        // Track initial graph state
        document.llmRecording.initialGraphState = document.visibleGraph.createSchema()
        
        // Create the task and set it on the manager
        self.currentTask =  getOpenAIStreamingTask(request: request, document: document)
    }
    
    @MainActor
    private func getOpenAIStreamingTask(request: OpenAIRequest,
                                        document: StitchDocumentViewModel) -> Task<Void, Never>? {
        
        Task(priority: .high) { [weak self] in
            
            guard let aiManager = self else {
                log("getOpenAIStreamingTask: no aiManager")
                return
            }
            
            do {
                try await aiManager.makeOpenAIStreamingRequest(request,
                                                document: document)
                
                log("OpenAI Request succeeded")
                
                // Handle successful response
                // Note: does not fire until we properly handle the whole request
                try aiManager.openAIStreamingCompleted(
                    // steps: steps,
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
            } // catch
         
            // Whether we succeeded or failed,
            // reset "is generating AI node" on the node menu.
            await MainActor.run { [weak document] in
                document?.insertNodeMenuState.isGeneratingAIResult = false
            }
            
        }
    }
    
    
    @MainActor
    func getOpenAIURLRequest(request: OpenAIRequest,
                             attempt: Int) -> Either<URLRequest> {
        
        let config = request.config
        let prompt = request.prompt
        let systemPrompt = request.systemPrompt
        
        // Validate API URL
        guard let openAIAPIURL = URL(string: OPEN_AI_BASE_URL) else {
            return .failure(StitchAIManagerError.invalidURL(request))
        }
        
        // Configure request headers and parameters
        var urlRequest = URLRequest(url: openAIAPIURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(self.secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let payloadAttempt = Either<StitchAIRequest>.init(catching: {
            try StitchAIRequest(secrets: secrets,
                                userPrompt: prompt,
                                systemPrompt: systemPrompt)
        })
        
        switch payloadAttempt {
            
        case .success(let payload):
            return .init {
                let encoder = JSONEncoder()
    //            encoder.outputFormatting = [.withoutEscapingSlashes]
                let jsonData = try encoder.encode(payload)
                urlRequest.httpBody = jsonData
                log("Making request attempt \(attempt) of \(config.maxRetries)")
                return urlRequest
            }
        
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Execute the API request with retry logic
    @MainActor
    func makeOpenAIStreamingRequest(_ request: OpenAIRequest,
                                    attempt: Int = 1,
                                    lastCapturedError: String? = nil,
                                    document: StitchDocumentViewModel) async throws {
        
        let config = request.config
                
        // Check if we've exceeded retry attempts
        guard attempt <= config.maxRetries else {
            log("All StitchAI retry attempts exhausted")
            SentrySDK.capture(message: "All StitchAI retry attempts exhausted")
            throw StitchAIManagerError.maxRetriesError(request.config.maxRetries, lastCapturedError ?? "")
        }
        
        let urlRequestAttempt: Either<URLRequest> = self.getOpenAIURLRequest(request: request, attempt: attempt)
        
        switch urlRequestAttempt {
        
        case .failure(let error):
            throw error
            
        case .success(let urlRequest):
            do {
                try await self.startOpenAIStreamingRequest(for: urlRequest)
            } catch {
                // Async because we will retry request on timeout-errors
                try await self.handleOpenAIStreamingRequestError(
                    error,
                    attempt: attempt,
                    request: request,
                    document: document)
            }
        }
                
        // TODO: MAY 22: without a response, how do handle rate limit or server errors?
//        // Check HTTP status code
//        if let httpResponse = response as? HTTPURLResponse,
//           !(200...299).contains(httpResponse.statusCode) {
//            // Retry on rate limit or server errors
//            if httpResponse.statusCode == 429 || // Rate limit
//                httpResponse.statusCode >= 500 {  // Server error
//                log("StitchAI Request failed with status code: \(httpResponse.statusCode)", .logToServer)
//                log("Retrying in \(config.retryDelay) seconds")
//                
//                return try await self.retryMakeRequest(
//                    request,
//                    currentAttempts: attempt,
//                    lastError: StitchAIManagerError.apiResponseError.description,
//                    document: document)
//            }
//        }
        
    }
        
    private func handleOpenAIStreamingRequestError(_ error: Error,
                                                   attempt: Int,
                                                   request: OpenAIRequest,
                                                   document: StitchDocumentViewModel) async throws {
                
        log("OpenAI request failed: \(error)")
        
        guard let error = error as NSError? else {
            // If we don't have an NSError, treat error as invalid url ?
            throw StitchAIManagerError.invalidURL(request)
        }
        
        // Handle network errors
        
        // Don't show error for cancelled requests
        if error.code == NSURLErrorCancelled {
            throw StitchAIManagerError.requestCancelled(request)
        }
        
        // Handle timeout errors
        else if error.code == NSURLErrorTimedOut {
            log("Timeout error count: \(attempt)")
            
            if attempt > request.config.maxTimeoutErrors {
                throw StitchAIManagerError.multipleTimeoutErrors(request, error.localizedDescription)
            }
            
            log("StitchAI Request timed out: \(error.localizedDescription)", .logToServer)
            log("Retrying in \(request.config.retryDelay) seconds")
            
            try await self.retryMakeOpenAIStreamingRequest(
                request,
                currentAttempts: attempt,
                lastError: error.localizedDescription,
                document: document)
        }
        
        // Handle network connection errors
       else  if error.code == NSURLErrorNotConnectedToInternet ||
            error.code == NSURLErrorNetworkConnectionLost {
            throw StitchAIManagerError.internetConnectionFailed(request)
        }
        
        // Handle other errors
        else {
            throw StitchAIManagerError.other(request, error)
        }
    }
    
    private func retryMakeOpenAIStreamingRequest(_ request: OpenAIRequest,
                                                 currentAttempts: Int,
                                                 lastError: String,
                                                 document: StitchDocumentViewModel) async throws {
        let config = request.config
        // Calculate exponential backoff delay: 2^attempt * base delay
        let backoffDelay = pow(2.0, Double(currentAttempts)) * config.retryDelay
        // Cap the maximum delay at 30 seconds
        let cappedDelay = min(backoffDelay, 30.0)
        
        log("Retrying request with backoff delay: \(cappedDelay) seconds")
        try await Task.sleep(nanoseconds: UInt64(cappedDelay * Double(nanoSecondsInSecond)))
        
        try await self.makeOpenAIStreamingRequest(request,
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
