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
    
    /// Default configuration with standard retry settings
    static let `default` = OpenAIRequestConfig(
        maxRetries: 3,
        timeoutInterval: 30,
        retryDelay: 2,
        maxTimeoutErrors: 3
    )
}

// Note: an event is usually not a long-lived data structure; but this is used for retry attempts.
/// Main event handler for initiating OpenAI API requests
struct OpenAIRequest {
    private let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    let prompt: String             // User's input prompt
    let systemPrompt: String       // System-level instructions loaded from file
    let schema: JSON              // JSON schema for response validation
    let config: OpenAIRequestConfig // Request configuration settings
    
    /// Initialize a new request with prompt and optional configuration
    init(prompt: String,
         config: OpenAIRequestConfig = .default) {
        self.prompt = prompt
        self.config = config
        
        // Load system prompt from bundled file
        var loadedPrompt = ""
        if let filePath = Bundle.main.path(forResource: "SYSTEM_PROMPT", ofType: "txt") {
            loadedPrompt = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
        }
        self.systemPrompt = loadedPrompt
        
        // Load JSON schema for response validation
        var loadedSchema = JSON()
        if let jsonFilePath = Bundle.main.path(forResource: "StitchStructuredOutputSchema", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: jsonFilePath)) {
            loadedSchema = JSON(data)
        }
        self.schema = loadedSchema
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
                let data = try await manager.makeRequest(request)

                // Handle successful response
                // TODO: need this to be await so mainactor call below isn't called
                try manager.openAIRequestCompleted(
                    originalPrompt: request.prompt,
                    data: data
                )
            } catch {
                log("StitchAI handleRequest error: \(error.localizedDescription)", .logToServer)
                
                await MainActor.run { [weak self] in
                    guard let state = self?.documentDelegate else { return }
                    
                    if let error = error as? StitchAIManagerError {
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
    private func makeRequest(_ request: OpenAIRequest,
                             attempt: Int = 1) async throws -> Data? {
        let config = request.config
        let prompt = request.prompt
        let schema = request.schema
        let systemPrompt = request.systemPrompt
        
        // Check if we've exceeded retry attempts
        guard attempt <= config.maxRetries else {
            log("All StitchAI retry attempts exhausted")
            SentrySDK.capture(message: "All StitchAI retry attempts exhausted")
            
            throw StitchAIManagerError.maxRetriesError(request.config.maxRetries)
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
        let payload: [String: Any] = [
            "model": self.secrets.openAIModel,
            "n": 1,
            "temperature": 0.5,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "VisualProgrammingActions",
                    "schema": schema.object
                ]
            ],
            "messages": [
                ["role": "system", "content": systemPrompt + "Make sure your response follows this schema: \(String(describing: schema.string))"],
                ["role": "user", "content": prompt]
            ]
        ]
        
        // Serialize and send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes])
            urlRequest.httpBody = jsonData
            log("Making request attempt \(attempt) of \(config.maxRetries)")
            // log("Request payload: \(payload.description)")
        } catch {
            throw StitchAIManagerError.jsonEncodingError(request, error)
        }
        
        let data: Data?
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
                        throw StitchAIManagerError.multipleTimeoutErrors(request)
                    }
                    
                    log("StitchAI Request timed out: \(error.localizedDescription)", .logToServer)
                    log("Retrying in \(config.retryDelay) seconds")
                    
                    try await Task.sleep(nanoseconds: UInt64(config.retryDelay * Double(nanoSecondsInSecond)))
                    return try await self.makeRequest(request,
                                                      attempt: attempt + 1)
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
                
                try await Task.sleep(nanoseconds: UInt64(config.retryDelay * Double(nanoSecondsInSecond)))
                return try await self.makeRequest(request,
                                                  attempt: attempt + 1)
            }
        }
        
        log("OpenAI Request succeeded")
        return data
    }
    
    /// Main handler for completed requests
    @MainActor
    func openAIRequestCompleted(originalPrompt: String,
                                data: Data?) throws {
        guard let data = data else {
            self.documentDelegate?
                .showErrorModal(
                message: "No data received",
                userPrompt: originalPrompt
            )
            
            self.documentDelegate?
                .handleError(NSError(domain: "OpenAIRequestCompleted",
                                     code: 0,
                                     userInfo: nil))
            return
        }
        
        // log raw JSON response
        let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
        log("OpenAIRequestCompleted: Full JSON Response:")
        log("----------------------------------------")
        log(jsonResponse)
        log("----------------------------------------")
        log("OpenAIRequestCompleted: JSON RESPONSE: \(jsonResponse)")
        
        let stepsFromResponse = try data.getOpenAISteps()
        log("JSON parsing succeeded on first attempt")
        try self.documentDelegate?
            .handleSuccessfulParse(steps: stepsFromResponse,
                                   originalPrompt: originalPrompt)
    }
}

// MARK: - Extensions

extension StitchDocumentViewModel {
    /// Process successfully parsed response data
    /// How we do this:
    /// 1. We receive the `LLMStepActions`, which we decoded from the JSON sent to us by OpenAI
    /// 2. We parse these `LLMStepActions` into `[StepTypeAction]` which is the more specific data structure we like to work with
    /// 3. We validate the `[StepTypeAction]`, e.g. make sure model did not try to use a NodeType that is unavailable for a given Patch
    /// 4. If all this succeeds, ONLY THEN do we apply the `[StepTypeAction]` to the state (fka `handleLLMStepAction`
    @MainActor func handleSuccessfulParse(steps: LLMStepActions,
                                          originalPrompt: String) throws {
        log("OpenAIRequestCompleted: stepsFromReponse:")
        for step in steps {
            log(step.description)
        }
        
        let parsedSteps: [StepTypeAction]
        
        do {
            parsedSteps = try steps.map { step in
                try StepTypeAction.fromStep(step)
            }
        } catch {
            log("StitchAI handleSuccessfulParse error: could not parse step with error: \(error.localizedDescription)")
            
            // TODO: JAN 30: retry the whole prompt; OpenAI might have given us bad data; e.g. specified a non-existent nodeType
            // Note that this can also be from a parsing error on our side, e.g. we incorrectly read the data OpenAI sent
            try self.handleRetry(prompt: originalPrompt)
            return
        }
        
        // If we successfully parsed the JSON and LLMStepActions,
        // we should close the insert-node-menu,
        // since we're not doing any retries.
        self.graphUI.reduxFocusedField = nil
        self.graphUI.insertNodeMenuState.show = false
        self.graphUI.insertNodeMenuState.isGeneratingAINode = false

        log(" Storing Original AI Generated Actions ")
        log(" Original Actions to store: \(steps.asJSONDisplay())")
        self.llmRecording.actions = parsedSteps
        self.llmRecording.promptState.prompt = originalPrompt
        
        self.validateAndApplyActions(parsedSteps)
    }
    
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
            nodeType: \(nodeType?.display ?? "nil")
        )
        """
    }
}
