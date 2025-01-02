//
//  OpenAIRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation
@preconcurrency import SwiftyJSON
import SwiftUI

struct OpenAIRequestConfig {
    let maxRetries: Int
    let timeoutInterval: TimeInterval
    let retryDelay: TimeInterval
    
    static let `default` = OpenAIRequestConfig(
        maxRetries: 3,
        timeoutInterval: 30,
        retryDelay: 2
    )
}

struct MakeOpenAIRequest: StitchDocumentEvent {
    let prompt: String
    let systemPrompt: String
    let schema: JSON
    let config: OpenAIRequestConfig
    
    init(prompt: String, config: OpenAIRequestConfig = .default) {
        self.prompt = prompt
        self.config = config
        
        // Load system prompt
        var loadedPrompt = ""
        if let filePath = Bundle.main.path(forResource: "SYSTEM_PROMPT", ofType: "txt") {
            loadedPrompt = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
        }
        self.systemPrompt = loadedPrompt
        
        // Load schema
        var loadedSchema = JSON()
        if let jsonFilePath = Bundle.main.path(forResource: "StitchStructuredOutputSchema", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: jsonFilePath)) {
            loadedSchema = JSON(data)
        }
        self.schema = loadedSchema
    }
    
    @MainActor func makeRequest(attempt: Int = 1, state: StitchDocumentViewModel) {
        guard attempt <= config.maxRetries else {
            print("All retry attempts exhausted")
            state.showErrorModal(
                message: "Request failed after \(config.maxRetries) attempts",
                userPrompt: prompt,
                jsonResponse: nil
            )
            state.stitchAI.promptState.isGenerating = false
            return
        }
        
        guard let openAIAPIURL = URL(string: OPEN_AI_BASE_URL) else {
            state.showErrorModal(
                message: "Invalid URL",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: OPENAI_API_KEY_NAME),
              !apiKey.isEmpty else {
            state.showErrorModal(
                message: "No API Key found or API Key is empty",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }
        
        var request = URLRequest(url: openAIAPIURL)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": OPEN_AI_MODEL,
            "n": 1,
            "temperature": 1,
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
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes])
            request.httpBody = jsonData
            print("Making request attempt \(attempt) of \(config.maxRetries)")
            print("Request payload: \(payload.description)")
        } catch {
            state.showErrorModal(
                message: "Error encoding JSON: \(error.localizedDescription)",
                userPrompt: prompt,
                jsonResponse: nil
            )
            return
        }
        
        if attempt == 1 {
            state.stitchAI.promptState.isGenerating = true
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    // Check if it's a timeout error
                    if error.code == NSURLErrorTimedOut ||
                       error.code == NSURLErrorNetworkConnectionLost {
                        print("Request failed: \(error.localizedDescription)")
                        print("Retrying in \(config.retryDelay) seconds")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + config.retryDelay) {
                            self.makeRequest(attempt: attempt + 1, state: state)
                        }
                        return
                    }
                    
                    // Handle other errors
                    state.showErrorModal(
                        message: "Request error: \(error.localizedDescription)",
                        userPrompt: prompt,
                        jsonResponse: nil
                    )
                    state.stitchAI.promptState.isGenerating = false
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    if httpResponse.statusCode == 429 || // Rate limit
                       httpResponse.statusCode >= 500 {  // Server error
                        print("Request failed with status code: \(httpResponse.statusCode)")
                        print("Retrying in \(config.retryDelay) seconds")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + config.retryDelay) {
                            self.makeRequest(attempt: attempt + 1, state: state)
                        }
                        return
                    }
                }
                
                print("Request succeeded")
                // Success case - dispatch completion event
                dispatch(OpenAIRequestCompleted(
                    originalPrompt: prompt,
                    data: data,
                    error: error
                ))
            }
        }.resume()
    }
    
    func handle(state: StitchDocumentViewModel) {
        makeRequest(state: state)
    }
}

struct OpenAIRequestCompleted: StitchDocumentEvent {
    let originalPrompt: String
    let data: Data?
    let error: Error?
    
    func handle(state: StitchDocumentViewModel) {
        // We've finished generating an OpenAI response from the prompt
        state.stitchAI.promptState.isGenerating = false
        
        if let error = error {
            state.showErrorModal(
                message: "Request error: \(error.localizedDescription)",
                userPrompt: originalPrompt,
                jsonResponse: nil
            )
            return
        }
        
        guard let data = data else {
            state.showErrorModal(
                message: "No data received",
                userPrompt: originalPrompt,
                jsonResponse: nil
            )
            return
        }
        
        let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
        log("OpenAIRequestCompleted: JSON RESPONSE: \(jsonResponse)")
        
        let (stepsFromResponse, error) = data.getOpenAISteps()
        
        guard let stepsFromResponse = stepsFromResponse else {
            state.showErrorModal(
                message: error?.localizedDescription ?? "",
                userPrompt: originalPrompt,
                jsonResponse: jsonResponse
            )
            return
        }
        
        log("OpenAIRequestCompleted: stepsFromReponse:")
        for step in stepsFromResponse {
            log(step.description)
        }
        
        var canvasItemsAdded = 0
        stepsFromResponse.forEach { step in
            canvasItemsAdded = state.handleLLMStepAction(
                step,
                canvasItemsAdded: canvasItemsAdded
            )
        }
        
        state.closeStitchAIModal()
    }
}

extension Data {
    func getOpenAISteps(attempt: Int = 1, maxAttempts: Int = 3, delaySeconds: TimeInterval = 1) -> (LLMStepActions?, Error?) {
        print("Parsing JSON attempt \(attempt) of \(maxAttempts)")
        
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: self)
            
            guard let firstChoice = response.choices.first else {
                print("JSON parsing failed: No choices available")
                if attempt < maxAttempts {
                    print("Retrying JSON parse in \(delaySeconds) seconds")
                    Thread.sleep(forTimeInterval: delaySeconds)
                    return getOpenAISteps(attempt: attempt + 1, maxAttempts: maxAttempts, delaySeconds: delaySeconds)
                }
                return (nil, nil)
            }
            
            do {
                let contentJSON = try firstChoice.message.parseContent()
                print("JSON parsing succeeded")
                return (contentJSON.actions, nil)
            } catch {
                print("JSON parsing failed: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    print("Retrying JSON parse in \(delaySeconds) seconds")
                    Thread.sleep(forTimeInterval: delaySeconds)
                    return getOpenAISteps(attempt: attempt + 1, maxAttempts: maxAttempts, delaySeconds: delaySeconds)
                }
                return (nil, error)
            }
            
        } catch {
            print("JSON parsing failed: \(error.localizedDescription)")
            if attempt < maxAttempts {
                print("Retrying JSON parse in \(delaySeconds) seconds")
                Thread.sleep(forTimeInterval: delaySeconds)
                return getOpenAISteps(attempt: attempt + 1, maxAttempts: maxAttempts, delaySeconds: delaySeconds)
            }
            return (nil, error)
        }
    }
}

extension Stitch.Step: CustomStringConvertible {
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
