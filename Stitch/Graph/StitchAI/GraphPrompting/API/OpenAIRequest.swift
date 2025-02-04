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
struct MakeOpenAIRequest: StitchDocumentEvent {
    private let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
    let prompt: String             // User's input prompt
    let systemPrompt: String       // System-level instructions loaded from file
    let schema: JSON              // JSON schema for response validation
    let config: OpenAIRequestConfig // Request configuration settings
    private let apiKey: String
    private let model: String
    @MainActor static var timeoutErrorCount = 0

    /// Initialize a new request with prompt and optional configuration
    init(prompt: String, config: OpenAIRequestConfig = .default) {
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
        
        self.apiKey = Secrets.openAIAPIKey
        self.model = Secrets.openAIModel
    }

    
    /// Execute the API request with retry logic
    @MainActor func makeRequest(attempt: Int = 1, state: StitchDocumentViewModel) {
        // Check if a request is already in progress
        guard !OpenAIRequestManager.isRequestInProgress else {
            log("A request is already in progress. Skipping this request.")
            return
        }

        // Cancel any existing request before starting a new one
        OpenAIRequestManager.cancelCurrentRequest()
        
        // Set the flag to indicate a request is in progress
        OpenAIRequestManager.isRequestInProgress = true
        state.graphUI.insertNodeMenuState.isGeneratingAINode = true

        // Validate API credentials
        guard !apiKey.isEmpty, !model.isEmpty else {
            state.showErrorModal(
                message: "Missing OpenAI credentials. Please check your environment configuration.",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }

        // Check if we've exceeded retry attempts
        guard attempt <= config.maxRetries else {
            log("All StitchAI retry attempts exhausted")
            SentrySDK.capture(message: "All StitchAI retry attempts exhausted")
            state.showErrorModal(
                message: "Request failed after \(config.maxRetries) attempts. Please check your internet connection and try again.",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }
        
        // Validate API URL
        guard let openAIAPIURL = URL(string: OPEN_AI_BASE_URL) else {
            state.showErrorModal(
                message: "Invalid URL",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }

        // Configure request headers and parameters
        var request = URLRequest(url: openAIAPIURL)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Construct request payload
        let payload: [String: Any] = [
            "model": model,
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
            request.httpBody = jsonData
            log("Making request attempt \(attempt) of \(config.maxRetries)")
           // log("Request payload: \(payload.description)")
        } catch {
            state.showErrorModal(
                message: "Error encoding JSON: \(error.localizedDescription)",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }
                
        // Create data task and store it
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                // Reset the flag when the request completes
                OpenAIRequestManager.isRequestInProgress = false
                OpenAIRequestManager.currentTask = nil

                // Handle network errors
                if let error = error as NSError? {
                    // Don't show error for cancelled requests
                    if error.code == NSURLErrorCancelled {
                        state.graphUI.insertNodeMenuState.isGeneratingAINode = false
                        return
                    }
                    
                    // Handle timeout errors
                    if error.code == NSURLErrorTimedOut {
                        Self.timeoutErrorCount += 1
                        log("Timeout error count: \(Self.timeoutErrorCount)")
                        
                        if Self.timeoutErrorCount >= config.maxTimeoutErrors {
                            state.showErrorModal(
                                message: "Multiple timeout errors occurred. Please check your internet connection and try again later.",
                                userPrompt: prompt,
                                jsonResponse: nil
                            )
                            state.graphUI.insertNodeMenuState.isGeneratingAINode = false
                            Self.timeoutErrorCount = 0  // Reset counter
                            return
                        }
                        
                        log("StitchAI Request timed out: \(error.localizedDescription)", .logToServer)
                        log("Retrying in \(config.retryDelay) seconds")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + config.retryDelay) {
                            self.makeRequest(attempt: attempt + 1, state: state)
                        }
                        return
                    }
                    
                    // Handle network connection errors
                    if error.code == NSURLErrorNotConnectedToInternet ||
                       error.code == NSURLErrorNetworkConnectionLost {
                        state.showErrorModal(
                            message: "No internet connection. Please try again when your connection is restored.",
                            userPrompt: prompt,
                            jsonResponse: nil
                        )
                        // Reset to Submit Prompt state
                        state.graphUI.insertNodeMenuState.isGeneratingAINode = false
                        return
                    }
                    
                    // Handle other errors
                    state.showErrorModal(
                        message: "OpenAI Request error: \(error.localizedDescription)",
                        userPrompt: prompt,
                        jsonResponse: nil
                    )

                    state.graphUI.insertNodeMenuState.isGeneratingAINode = false
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    // Retry on rate limit or server errors
                    if httpResponse.statusCode == 429 || // Rate limit
                       httpResponse.statusCode >= 500 {  // Server error
                        log("StitchAI Request failed with status code: \(httpResponse.statusCode)", .logToServer)
                        log("Retrying in \(config.retryDelay) seconds")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + config.retryDelay) {
                            self.makeRequest(attempt: attempt + 1, state: state)
                        }
                        return
                    }
                }
                
                log("OpenAI Request succeeded")
                // Handle successful response
                dispatch(OpenAIRequestCompleted(
                    originalPrompt: prompt,
                    data: data,
                    error: error
                ))
            }
        }
        
        OpenAIRequestManager.currentTask = task
        task.resume()
    }
    
    /// Entry point for handling the request event
    func handle(state: StitchDocumentViewModel) {
        makeRequest(state: state)
    }
    
}

/// Event handler for completed OpenAI requests
struct OpenAIRequestCompleted: StitchDocumentEvent {
    let originalPrompt: String
    let data: Data?
    let error: Error?
    let maxParsingAttempts = 3
    let parsingRetryDelay: TimeInterval = 1
    
    /// Retry parsing JSON response with delay using dispatch queue
    @MainActor private func retryParsing(data: Data, attempt: Int, state: StitchDocumentViewModel) {
        log("Retrying JSON parsing, attempt \(attempt) of \(maxParsingAttempts)", .logToServer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + parsingRetryDelay) {
            let (stepsFromResponse, error) = data.getOpenAISteps()
            
            if let stepsFromResponse = stepsFromResponse {
                log("StitchAI JSON parsing succeeded on retry \(attempt)")
                self.handleSuccessfulParse(steps: stepsFromResponse, state: state)
            } else if attempt < self.maxParsingAttempts {
                log("StitchAI JSON parsing failed on retry \(attempt): \(error?.localizedDescription ?? "")", .logToServer)
                self.retryParsing(data: data, attempt: attempt + 1, state: state)
            } else {
                log("StitchAI All parsing retries exhausted for \(self.originalPrompt)", .logToServer)
                
                state.showErrorModal(
                    message: error?.localizedDescription ?? "Failed to parse response after \(self.maxParsingAttempts) attempts",
                    userPrompt: self.originalPrompt,
                    jsonResponse: String(data: data, encoding: .utf8) ?? ""
                )
                self.handleError(error ?? NSError(domain: "OpenAIRequestCompleted", code: 0, userInfo: nil), state: state)
            }
        }
    }
    
    /// Process successfully parsed response data
    /// How we do this:
    /// 1. We receive the `LLMStepActions`, which we decoded from the JSON sent to us by OpenAI
    /// 2. We parse these `LLMStepActions` into `[StepTypeAction]` which is the more specific data structure we like to work with
    /// 3. We validate the `[StepTypeAction]`, e.g. make sure model did not try to use a NodeType that is unavailable for a given Patch
    /// 4. If all this succeeds, ONLY THEN do we apply the `[StepTypeAction]` to the state (fka `handleLLMStepAction`
    @MainActor func handleSuccessfulParse(steps: LLMStepActions,
                                          state: StitchDocumentViewModel) {
        log("OpenAIRequestCompleted: stepsFromReponse:")
        for step in steps {
            log(step.description)
        }
        
        let parsedSteps: [StepTypeAction] = steps.compactMap { StepTypeAction.fromStep($0) }
        
        let couldNotParseAllSteps = (parsedSteps.count != steps.count)
        if couldNotParseAllSteps {
            // TODO: JAN 30: retry the whole prompt; OpenAI might have given us bad data; e.g. specified a non-existent nodeType
            // Note that this can also be from a parsing error on our side, e.g. we incorrectly read the data OpenAI sent
            state.handleRetry()
            return
        }
        
        // If we successfully parsed the JSON and LLMStepActions,
        // we should close the insert-node-menu,
        // since we're not doing any retries.
        state.graphUI.reduxFocusedField = nil
        state.graphUI.insertNodeMenuState.show = false
        state.graphUI.insertNodeMenuState.isGeneratingAINode = false

        log(" Storing Original AI Generated Actions ")
        log(" Original Actions to store: \(steps.asJSONDisplay())")
        state.llmRecording.actions = parsedSteps
        state.llmRecording.promptState.prompt = originalPrompt
        
        state.validateAndApplyActions(parsedSteps)
    }
    
    /// Main handler for completed requests
    func handle(state: StitchDocumentViewModel) {
        
        if let error = error {
            state.showErrorModal(
                message: "Request error: \(error.localizedDescription)",
                userPrompt: originalPrompt,
                jsonResponse: nil
            )
            handleError(error, state: state)
            return
        }
        
        guard let data = data else {
            state.showErrorModal(
                message: "No data received",
                userPrompt: originalPrompt,
                jsonResponse: nil
            )
            handleError(NSError(domain: "OpenAIRequestCompleted", code: 0, userInfo: nil), state: state)
            return
        }
        
        // log raw JSON response
        let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
        log("OpenAIRequestCompleted: Full JSON Response:")
        log("----------------------------------------")
        log(jsonResponse)
        log("----------------------------------------")
        log("OpenAIRequestCompleted: JSON RESPONSE: \(jsonResponse)")
        
        let (stepsFromResponse, error) = data.getOpenAISteps()
        
        if let stepsFromResponse = stepsFromResponse {
            log("JSON parsing succeeded on first attempt")
            handleSuccessfulParse(steps: stepsFromResponse, state: state)
        } else {
            log("Initial StitchAI JSON parsing failed: \(error?.localizedDescription ?? "")", .logToServer)
            log("Starting parsing retries")
            retryParsing(data: data, attempt: 1, state: state)
        }
    }
    
    @MainActor func handleError(_ error: Error, state: StitchDocumentViewModel) {
        log("Error generating graph with StitchAI: \(error)", .logToServer)
        state.graphUI.insertNodeMenuState.show = false
        state.graphUI.insertNodeMenuState.isGeneratingAINode = false
    }
}

// MARK: - Extensions

extension Data {
    /// Parse OpenAI response data into step actions
    func getOpenAISteps() -> (LLMStepActions?, Error?) {
        log("StitchAI Parsing JSON")
        
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: self)
            
            guard let firstChoice = response.choices.first else {
                log("StitchAI JSON parsing failed: No choices available", .logToServer)
                return (nil, nil)
            }
            
            do {
                let contentJSON = try firstChoice.message.parseContent()
                log("StitchAI JSON parsing succeeded")
                return (contentJSON.steps, nil)
            } catch {
                log("StitchAI JSON parsing failed: \(error.localizedDescription)", .logToServer)
                return (nil, error)
            }
            
        } catch {
            log("StitchAI JSON parsing failed: \(error.localizedDescription)", .logToServer)
            return (nil, error)
        }
    }
}

extension Stitch.Step: CustomStringConvertible {
    /// Provides detailed string representation of a Step
    public var description: String {
        return """
        Step(
            stepType: "\(stepType)",
            nodeId: \(nodeId ?? "nil"),
            nodeName: \(nodeName ?? "nil"),
            port: \(port?.value ?? "nil"),
            fromNodeId: \(fromNodeId ?? "nil"),
            toNodeId: \(toNodeId ?? "nil"),
            value: \(String(describing: value)),
            nodeType: \(nodeType ?? "nil")
        )
        """
    }
}

@MainActor class OpenAIRequestManager {
    static var currentTask: URLSessionDataTask?
    static var isRequestInProgress = false
    
    static func cancelCurrentRequest() {
        if currentTask != nil {
            log("Cancelling current OpenAI request")
            currentTask?.cancel()
            currentTask = nil
            isRequestInProgress = false
        }
    }
}
