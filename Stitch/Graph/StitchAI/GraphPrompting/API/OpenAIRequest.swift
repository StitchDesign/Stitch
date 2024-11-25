//
//  OpenAIRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/12/24.
//

import Foundation
import SwiftyJSON

struct MakeOpenAIRequest: StitchDocumentEvent {
    let prompt: String
    
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
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        guard let responseSchema: [String: Any] = try? JSONSerialization.jsonObject(with: Data(VISUAL_PROGRAMMING_ACTIONS.utf8), options: []) as? [String: Any] else {
            
            state.showErrorModal(message: "Failed to parse VISUAL_PROGRAMMING_ACTIONS JSON",
                                 userPrompt: prompt,
                                 jsonResponse: VISUAL_PROGRAMMING_ACTIONS)
            return
        }
    
       
        let body = getOpenAIRequestBody(prompt: prompt,
                                        responseSchema: responseSchema)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
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


func getOpenAIRequestBody(prompt: String,
                          responseSchema: [String: Any]) -> [String: Any] {
    
    let body: [String: Any] = [
        "model": OPEN_AI_MODEL,
        "messages": [
            [
                "role": "system",
                "content": SYSTEM_PROMPT
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ],
        "response_format": [
            "type": "json_schema",
            "json_schema": [
                "name": "visual_programming_actions_schema",
                "schema": responseSchema,
                "strict": true
            ]
        ]
    ]
    
    return body
}

struct OpenAIRequestCompleted: StitchDocumentEvent {
    let originalPrompt: String
    let data: Data?
    let error: Error?
    
    func handle(state: StitchDocumentViewModel) {
        
        // We've finished generating an OpenAI response from the prompt
        state.stitchAI.promptState.isGenerating = false
        
        // Error from HTTP Request
        if let error: Error = error {
            state.showErrorModal(message: "Request error: \(error.localizedDescription)",
                                 userPrompt: originalPrompt,
                                 jsonResponse: nil)
            return
        }
        
        guard let data: Data = data else {
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
            value: \(value),
            nodeType: \(nodeType ?? "nil")
        )
        """
    }
}
