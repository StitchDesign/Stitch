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
    let systemPrompt: String
    let schema: JSON
    
    init(prompt: String) {
        self.prompt = prompt
        
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
    
    func handle(state: StitchDocumentViewModel) {
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": "ft:gpt-4o-2024-08-06:adammenges::AdhLWSuL",
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
            print("JSON Request Payload:\n\(payload.description)")
        } catch {
            state.showErrorModal(message: "Error encoding JSON: \(error.localizedDescription)",
                               userPrompt: prompt,
                               jsonResponse: nil)
            return
        }
        
        state.stitchAI.promptState.isGenerating = true
        
        URLSession.shared.dataTask(with: request) { data, _, error in
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


extension Data {
    func getOpenAISteps() -> (LLMStepActions?, Error?) {
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: self)
            
            guard let firstChoice = response.choices.first else {
                print("getOpenAISteps: Invalid JSON structure: no choices available")
                return (nil, nil)
            }
            
            let contentJSON = try firstChoice.message.parseContent()
            // Update to use steps directly from jsonSchema
            return (contentJSON.actions, nil)
            
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
