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

let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"

/// Configuration settings for OpenAI API requests
struct OpenAIRequestConfig {
    let maxRetries: Int        // Maximum number of retry attempts for failed requests
    let timeoutInterval: TimeInterval   // Request timeout duration in seconds
    let retryDelay: TimeInterval       // Delay between retry attempts
    let maxTimeoutErrors: Int  // Maximum number of timeout errors before showing alert
    
    /// Default configuration with optimized retry settings
    static let `default` = OpenAIRequestConfig(
        maxRetries: 5,
        timeoutInterval: 30,
        retryDelay: 1,
        maxTimeoutErrors: 4
    )
}

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
         graph: GraphState) throws {
        self.prompt = prompt
        self.config = config
        
        // Load system prompt from bundled file
        let loadedPrompt = try StitchAIManager.systemPrompt(graph: graph)
        self.systemPrompt = loadedPrompt
    }
}

extension StitchAIManager {
    @MainActor func handleRequest(_ request: OpenAIRequest) {
        guard let currentDocument = self.documentDelegate else {
            return
        }
        
        // Set the flag to indicate a request is in progress
        currentDocument.graphUI.insertNodeMenuState.isGeneratingAINode = true
        
        self.currentTask = Task(priority: .high) { [weak self] in
            guard let manager = self else {
                return
            }
            
            do {
                let steps = try await manager.makeRequest(request)

                // Handle successful response
                try manager.openAIRequestCompleted(steps: steps,
                                                   originalPrompt: request.prompt)
            } catch {
                log("StitchAI handleRequest error: \(error.localizedDescription)", .logToServer)
                
                await MainActor.run { [weak self] in
                    guard let state = self?.documentDelegate else { return }
                    
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
                currentDocument?.graphUI.insertNodeMenuState.isGeneratingAINode = false
            }
        }
    }
    
    /// Execute the API request with retry logic
    @MainActor
    private func makeRequest(_ request: OpenAIRequest,
                             attempt: Int = 1,
                             lastCapturedError: String? = nil) async throws -> [StepTypeAction] {
        let config = request.config
        let prompt = request.prompt
        let systemPrompt = request.systemPrompt
        
        guard let document = self.documentDelegate else {
            throw StitchAIManagerError.documentNotFound(request) 
        }
        document.llmRecording.recentOpenAIRequestCompleted = false
        
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
                                          systemPrompt: systemPrompt)
        
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
            let result = try await URLSession.shared.data(for: urlRequest)
            data = result.0
            response = result.1
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
                                                           currentAttempts: attempt,
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
                                              currentAttempt: Int) async throws -> [StepTypeAction] {
        
        // Try to parse request
        // log raw JSON response
        let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
        log("OpenAIRequestCompleted: Full JSON Response:")
        log("----------------------------------------")
        log(jsonResponse)
        log("----------------------------------------")
        log("OpenAIRequestCompleted: JSON RESPONSE: \(jsonResponse)")
        
        do {
            let steps = try data.getOpenAISteps()
            let convertedSteps: [StepTypeAction] = try steps.map { step in
                try StepTypeAction.fromStep(step)
            }
            
            log("OpenAI Request succeeded")
            return convertedSteps
        } catch let error as StitchAIManagerError {
            log("StitchAIManager error parsing steps: \(error.description)")
            return try await self.retryMakeRequest(request,
                                                   currentAttempts: currentAttempt,
                                                   lastError: error.description)
        } catch {
            log("StitchAIManager unknown error parsing steps: \(error.localizedDescription)")
            return try await self.retryMakeRequest(request,
                                                   currentAttempts: currentAttempt,
                                                   lastError: error.localizedDescription)
        }
    }
    
    private func retryMakeRequest(_ request: OpenAIRequest,
                                  currentAttempts: Int,
                                  lastError: String) async throws -> [StepTypeAction] {
        let config = request.config
        try await Task.sleep(nanoseconds: UInt64(config.retryDelay * Double(nanoSecondsInSecond)))
        return try await self.makeRequest(request,
                                          attempt: currentAttempts + 1,
                                          lastCapturedError: lastError)
    }
    
    /// Process successfully parsed response data
    /// How we do this:
    /// 1. We receive the `LLMStepActions`, which we decoded from the JSON sent to us by OpenAI
    /// 2. We parse these `LLMStepActions` into `[StepTypeAction]` which is the more specific data structure we like to work with
    /// 3. We validate the `[StepTypeAction]`, e.g. make sure model did not try to use a NodeType that is unavailable for a given Patch
    /// 4. If all this succeeds, ONLY THEN do we apply the `[StepTypeAction]` to the state (fka `handleLLMStepAction`
    @MainActor
    func openAIRequestCompleted(steps: [StepTypeAction],
                                originalPrompt: String) throws {
        guard let document = self.documentDelegate else {
            return
        }
        
        // If we successfully parsed the JSON and LLMStepActions,
        // we should close the insert-node-menu,
        // since we're not doing any retries.
        document.graphUI.reduxFocusedField = nil
        document.graphUI.insertNodeMenuState.show = false
        document.graphUI.insertNodeMenuState.isGeneratingAINode = false

        log(" Storing Original AI Generated Actions ")
        log(" Original Actions to store: \(steps.asJSONDisplay())")
        document.llmRecording.actions = steps
        document.llmRecording.promptState.prompt = originalPrompt
        
        try document.validateAndApplyActions(steps)
        
        document.llmRecording.recentOpenAIRequestCompleted = true
    }
}

// MARK: - Extensions

extension StitchDocumentViewModel {
    @MainActor func handleError(_ error: Error) {
        log("Error generating graph with StitchAI: \(error)", .logToServer)
        self.graphUI.insertNodeMenuState.show = false
        self.graphUI.insertNodeMenuState.isGeneratingAINode = false
    }
}

extension Data {
    /// Parse OpenAI response data into step actions
    func getOpenAISteps() throws -> LLMStepActions {
        log("StitchAI Parsing JSON")
        
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: self)
        
        guard let firstChoice = response.choices.first else {
            throw StitchAIManagerError.emptySuccessfulResponse
        }
        
        let contentJSON = try firstChoice.message.parseContent()
        log("StitchAI JSON parsing succeeded")
        return contentJSON.steps
    }
}

extension Stitch.Step: CustomStringConvertible {
    /// Provides detailed string representation of a Step
    public var description: String {
        return """
        Step(
            stepType: "\(stepType)",
            nodeId: \(nodeId?.value.uuidString ?? "nil"),
            nodeName: \(nodeName?.asNodeKind.asLLMStepNodeName ?? "nil"),
            port: \(port?.asLLMStepPort() ?? "nil"),
            fromNodeId: \(fromNodeId?.value.uuidString ?? "nil"),
            toNodeId: \(toNodeId?.value.uuidString ?? "nil"),
            value: \(String(describing: value)),
            nodeType: \(valueType?.display ?? "nil")
        )
        """
    }
}
