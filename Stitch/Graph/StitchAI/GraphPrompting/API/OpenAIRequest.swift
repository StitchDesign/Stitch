//
//  OpenAIRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation
@preconcurrency import SwiftyJSON
import SwiftUI

struct MakeOpenAIRequest: StitchDocumentEvent {
    let prompt: String
    @State private var systemPrompt: String = ""
    @State private var schema: JSON = JSON()

    private func loadFiles() {
        if let filePath = Bundle.main.path(forResource: "SYSTEM_PROMPT", ofType: "txt") {
            do {
                systemPrompt = try String(contentsOfFile: filePath, encoding: .utf8)
            } catch {
//                alertMessage = "Failed to load system prompt: \(error.localizedDescription)"
//                showAlert = true
            }
        } else {
//            alertMessage = "System prompt file not found in the app bundle."
//            showAlert = true
        }

        if let jsonFilePath = Bundle.main.path(forResource: "StitchStructuredOutputSchema", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: jsonFilePath)) {
            schema = JSON(data)
        } else {
//            alertMessage = "Failed to load or parse the schema file."
//            showAlert = true
        }
    }

    
    func handle(state: StitchDocumentViewModel) {
        loadFiles()
        guard let openAIAPIURL = URL(string: OPEN_AI_BASE_URL) else {
            state.showErrorModal(message: "Invalid URL",
                               userPrompt: prompt,
                               jsonResponse: nil)
            return
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: OPENAI_API_KEY_NAME),
              !apiKey.isEmpty else {
            state.showErrorModal(message: "No API Key found or API Key is empty",
                               userPrompt: prompt,
                               jsonResponse: nil)
            return
        }
        
        var request = URLRequest(url: openAIAPIURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Parse the schema once
        guard let jsonData = VISUAL_PROGRAMMING_ACTIONS_SCHEMA.data(using: .utf8),
              let schemaDict = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String: Any] else {
            state.showErrorModal(message: "Failed to parse schema",
                                userPrompt: prompt,
                                jsonResponse: nil)
            return
        }

        print(schemaDict)
        if let prettyJsonData = try? JSONSerialization.data(withJSONObject: schemaDict, options: .prettyPrinted),
           let prettyPrintedStr = String(data: prettyJsonData, encoding: .utf8) {
            print(prettyPrintedStr)
        }
 
        
        // Construct the request payload
//        let payload: [String: Any] = [
//            "model": OPEN_AI_MODEL,
//            "n": 1,
//            "temperature": 0,
//            "response_format": [
//                "type": "json_schema",
//                "json_schema": [
//                    "name": "VisualProgrammingActions",
//                    "strict": true,
//                    "schema": schemaDict
//                ]
//            ],
//            "messages": [
//                ["role": "system", "content": systemPrompt],
//                ["role": "user", "content": prompt]
//            ]
//        ]
        
        let payload = JSON([
            "model": "ft:gpt-4o-2024-08-06:adammenges::AdhLWSuL",
            "n": 1,
            "temperature": 1,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "\(systemPrompt)\nResponse must conform to this JSON schema: \(schema.description)"],
                ["role": "user", "content": prompt]
            ]
        ])

        
        do {
            let jsonData = try payload.rawData()
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("Final JSON Request Body:\n\(jsonString)")
            }
            
        } catch {
            state.showErrorModal(message: "Error encoding JSON: \(error.localizedDescription)",
                               userPrompt: prompt,
                               jsonResponse: nil)
            return
        }
        
        state.stitchAI.promptState.isGenerating = true
        
        // Note: really, should return a proper `Effect` here
        URLSession.shared.dataTask(with: request) { data, _, error in
            // Make the request and dispatch (on the main thread) an action that will handle the request's result
            DispatchQueue.main.async {
                dispatch(OpenAIRequestCompleted(originalPrompt: prompt, data: data, error: error))
            }
        }.resume()
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
            state.showErrorModal(message: "Request error: \(error.localizedDescription)",
                               userPrompt: originalPrompt,
                               jsonResponse: nil)
            return
        }
        
        guard let data = data else {
            state.showErrorModal(message: "No data received",
                               userPrompt: originalPrompt,
                               jsonResponse: nil)
            return
        }
        
        let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
        log("OpenAIRequestCompleted: JSON RESPONSE: \(jsonResponse)")
        
        let (stepsFromResponse, error) = data.getOpenAISteps()
        
        guard let stepsFromResponse = stepsFromResponse else {
            state.showErrorModal(message: error?.localizedDescription ?? "",
                               userPrompt: originalPrompt,
                               jsonResponse: jsonResponse)
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
                canvasItemsAdded: canvasItemsAdded)
        }
        
        state.closeStitchAIModal()
    }
}

private func sendOpenAIRequest(userMessage: String, systemPrompt: String, schema: JSON, apiKey: String) async throws -> Data {
    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
        throw URLError(.badURL)
    }

    let payload = JSON([
        "model": "ft:gpt-4o-2024-08-06:adammenges::AdhLWSuL",
        "n": 1,
        "temperature": 1,
        "response_format": ["type": "json_object"],
        "messages": [
            ["role": "system", "content": "\(systemPrompt)\nResponse must conform to this JSON schema: \(schema.description)"],
            ["role": "user", "content": userMessage]
        ]
    ])

    let jsonData = try payload.rawData()
    print("JSON Request Payload:\n\(payload.description)")

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = jsonData

    let (data, response) = try await URLSession.shared.data(for: request)

    // Check for empty data
    if data.isEmpty {
        throw NSError(domain: "MakeOpenAIRequest", code: 3, userInfo: [NSLocalizedDescriptionKey: "The response data is empty."])
    }

    // Log raw response
    if let httpResponse = response as? HTTPURLResponse {
        print("HTTP Response Status Code: \(httpResponse.statusCode)")
    }

    if let rawResponse = String(data: data, encoding: .utf8) {
        print("Raw Response: \(rawResponse)")
    }

    return data
}
extension Data {
    func getOpenAISteps() -> (LLMStepActions?, Error?) {
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: self)
            
            guard let firstChoice = response.choices.first else {
                print("getOpenAISteps: Invalid JSON structure: no choices available")
                return (nil, nil)
            }
            
            let contentJSON = try firstChoice.message.parseContent()
            
            return (contentJSON.steps, nil)
        } catch {
            print("getOpenAISteps: some error \(error.localizedDescription)")
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
