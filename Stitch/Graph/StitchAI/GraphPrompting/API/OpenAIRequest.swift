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
    
    @MainActor func handleRequest(_ request: OpenAIRequest) {
        guard let currentDocument = self.documentDelegate else {
            return
        }
        
        // Set the flag to indicate a request is in progress
        currentDocument.insertNodeMenuState.isGeneratingAINode = true
        
        // Track initial graph state
        currentDocument.llmRecording.initialGraphState = currentDocument.visibleGraph.createSchema()
        
        self.currentTask = Task(priority: .high) { [weak self] in
            guard let manager = self else {
                return
            }
            
            do {
                let steps = try await manager.makeRequest(request, graph: currentDocument.visibleGraph)
                
                log("OpenAI Request succeeded")
                
                // Handle successful response
                try manager.openAIRequestCompleted(steps: steps,
                                                   originalPrompt: request.prompt)
            } catch {
                log("StitchAI handleRequest error: \(error.localizedDescription)", .logToServer)
                
                await MainActor.run { [weak self] in
                    guard let state = self?.documentDelegate else { return }
                    
                    // Reset recording state
                    state.llmRecording = .init()
                    
                    // Reset checks which would later break new recording mode
                    state.insertNodeMenuState = InsertNodeMenuState()
                    
                    if let error = error as? StitchAIManagerError {
                        guard error.shouldDisplayModal else {
                            return
                        }
                        
                        state.showErrorModal(
                            message: error.description,
                            userPrompt: request.prompt
                        )
                    } else {
                        state.showErrorModal(
                            message: "StitchAI handleRequest unknown error: \(error)",
                            userPrompt: request.prompt
                        )
                    }
                }
            }
         
            await MainActor.run { [weak currentDocument] in
                currentDocument?.insertNodeMenuState.isGeneratingAINode = false
            }
        }
    }
    
    /// Execute the API request with retry logic
    @MainActor
    func makeRequest(_ request: OpenAIRequest,
                     attempt: Int = 1,
                     lastCapturedError: String? = nil,
                     graph: GraphState) async throws -> [Step] {
        
        let config = request.config
        let prompt = request.prompt
        let systemPrompt = request.systemPrompt
        
        guard let _ = self.documentDelegate else {
            throw StitchAIManagerError.documentNotFound(request)
        }
//        document.llmRecording.recentOpenAIRequestCompleted = false
        
        // Check if we've exceeded retry attempts
        guard attempt <= config.maxRetries else {
            log("All StitchAI retry attempts exhausted")
            SentrySDK.capture(message: "All StitchAI retry attempts exhausted")
            
            throw StitchAIManagerError.maxRetriesError(request.config.maxRetries, lastCapturedError ?? "")
        }
        
        // Validate API URL
        guard let openAIAPIURL = URL(string: OPEN_AI_BASE_URL) else {
            throw StitchAIManagerError.invalidURL(request)
        }
        
        // Configure request headers and parameters
        var urlRequest = URLRequest(url: openAIAPIURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(self.secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Construct request payload
        let payload = try StitchAIRequest(secrets: secrets,
                                          userPrompt: prompt,
                                          systemPrompt: systemPrompt,
                                          stream: config.stream)
        
        // Serialize and send request
        do {
            let encoder = JSONEncoder()
//            encoder.outputFormatting = [.withoutEscapingSlashes]
            let jsonData = try encoder.encode(payload)
            urlRequest.httpBody = jsonData
            log("Making request attempt \(attempt) of \(config.maxRetries)")
            // log("Request payload: \(payload.description)")
        } catch {
            throw StitchAIManagerError.jsonEncodingError(request, error)
        }
        
        let data: Data
        let response: URLResponse
        
        do {
            // Create data task and store it
            let startTime = Date()
            
            if config.stream {
                // NEW: stream data and print chunks as they arrive
                let result = try await self.streamData(for: urlRequest, graph: graph)
                data = result.0
                response = result.1
                // When streaming, use the parsed steps directly
                return result.2
            } else {
                let result = try await URLSession.shared.data(for: urlRequest)
                data = result.0
                response = result.1
            }
            
            let responseTime = Date().timeIntervalSince(startTime)
            log("OpenAI request completed in \(responseTime) seconds")
        } catch {
            log("OpenAI request failed: \(error)")
            
            // Handle network errors
            if let error = error as NSError? {
                // Don't show error for cancelled requests
                if error.code == NSURLErrorCancelled {
                    throw StitchAIManagerError.requestCancelled(request)
                }
                
                // Handle timeout errors
                if error.code == NSURLErrorTimedOut {
                    log("Timeout error count: \(attempt)")
                    
                    if attempt > config.maxTimeoutErrors {
                        throw StitchAIManagerError.multipleTimeoutErrors(request, error.localizedDescription)
                    }
                    
                    log("StitchAI Request timed out: \(error.localizedDescription)", .logToServer)
                    log("Retrying in \(config.retryDelay) seconds")
                    
                    return try await self.retryMakeRequest(request,
                                                           currentAttempts: attempt, graph: graph,
                                                           lastError: error.localizedDescription)
                }
                
                // Handle network connection errors
                if error.code == NSURLErrorNotConnectedToInternet ||
                    error.code == NSURLErrorNetworkConnectionLost {
                    throw StitchAIManagerError.internetConnectionFailed(request)
                }
                
                // Handle other errors
                throw StitchAIManagerError.other(request, error)
            }
            throw StitchAIManagerError.invalidURL(request)
        }
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            // Retry on rate limit or server errors
            if httpResponse.statusCode == 429 || // Rate limit
                httpResponse.statusCode >= 500 {  // Server error
                log("StitchAI Request failed with status code: \(httpResponse.statusCode)", .logToServer)
                log("Retrying in \(config.retryDelay) seconds")
                
                return try await self.retryMakeRequest(request,
                                                       currentAttempts: attempt,
                                                       graph: graph,
                                                       lastError: StitchAIManagerError.apiResponseError.description)
            }
        }
        
         return try await self.convertResponseToStepActions(request,
                                                            data: data,
                                                            currentAttempt: attempt)
    }
    
    // Convert data to decoded Step actions
    private func convertResponseToStepActions(_ request: OpenAIRequest,
                                              data: Data,
                                              currentAttempt: Int) async throws -> [Step] {
        
        // Try to parse request
        // log raw JSON response
        let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
        log("StitchAI Parsing JSON")
        
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let firstChoice = response.choices.first else {
            throw StitchAIManagerError.emptySuccessfulResponse
        }
        
        let contentJSON = try firstChoice.message.parseContent()
        log("StitchAI JSON parsing succeeded")
        return contentJSON.steps
    }
    
    private func retryMakeRequest(_ request: OpenAIRequest,
                                  currentAttempts: Int,
                                  graph: GraphState,
                                  lastError: String) async throws -> [Step] {
        let config = request.config
        // Calculate exponential backoff delay: 2^attempt * base delay
        let backoffDelay = pow(2.0, Double(currentAttempts)) * config.retryDelay
        // Cap the maximum delay at 30 seconds
        let cappedDelay = min(backoffDelay, 30.0)
        
        log("Retrying request with backoff delay: \(cappedDelay) seconds")
        try await Task.sleep(nanoseconds: UInt64(cappedDelay * Double(nanoSecondsInSecond)))
        
        return try await self.makeRequest(request,
                                          attempt: currentAttempts + 1,
                                          lastCapturedError: lastError,
                                          graph: graph)
    }
    
    /// Process successfully parsed response data
    /// How we do this:
    /// 1. We receive the `LLMStepActions`, which we decoded from the JSON sent to us by OpenAI
    /// 2. We parse these `LLMStepActions` into `[StepTypeAction]` which is the more specific data structure we like to work with
    /// 3. We validate the `[StepTypeAction]`, e.g. make sure model did not try to use a NodeType that is unavailable for a given Patch
    /// 4. If all this succeeds, ONLY THEN do we apply the `[StepTypeAction]` to the state (fka `handleLLMStepAction`
    @MainActor
    func openAIRequestCompleted(steps: [Step],
                                originalPrompt: String) throws {
        guard let document = self.documentDelegate else {
            return
        }
        
        // If we successfully parsed the JSON and LLMStepActions,
        // we should close the insert-node-menu,
        // since we're not doing any retries.
        document.reduxFocusedField = nil
        
        // Set auto-hiding flag before hiding menu
        document.insertNodeMenuState.isAutoHiding = true
        document.insertNodeMenuState.show = false
        document.insertNodeMenuState.isGeneratingAINode = false

        log(" Storing Original AI Generated Actions ")
        document.llmRecording.promptState.prompt = originalPrompt
        
        // Enable edit mode for actions after successful request
//        document.llmRecording.mode = .augmentation
        document.llmRecording.mode = .normal
        
        try document.validateAndApplyActions(steps,
                                             isNewRequest: true)
        
        document.encodeProjectInBackground()
    }
}
