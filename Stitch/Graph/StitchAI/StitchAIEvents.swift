//
//  StitchAIEvents.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation
import SwiftUI
import SwiftyJSON

extension StitchDocumentViewModel {
    
    @MainActor func openedStitchAIModal() {
        self.stitchAI.promptState.showModal = true
        self.graphUI.reduxFocusedField = .stitchAIPromptModal
    }
    
    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor func closedStitchAIModal() {
        let prompt = self.stitchAI.promptState.prompt
        
        self.stitchAI.promptState.showModal = false
        self.graphUI.reduxFocusedField = nil
        
        
        //HACK until we figure out why this is called twice
        if prompt == "" {
            return
        }
        makeAPIRequest(userInput: prompt)
        self.stitchAI.promptState.prompt = ""
    }
    
    @MainActor func makeAPIRequest(userInput: String) {
        stitchAI.promptState.isGenerating = true
        
        guard let openAIAPIURL = URL(string: OPEN_AI_BASE_URL) else {
            showErrorModal(message: "Invalid URL", userPrompt: userInput, jsonResponse: nil)
            return
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: OPENAI_API_KEY_NAME), !apiKey.isEmpty else {
            showErrorModal(message: "No API Key found or API Key is empty", userPrompt: userInput, jsonResponse: nil)
            return
        }
        
        var request = URLRequest(url: openAIAPIURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let responseSchema = try? JSONSerialization.jsonObject(with: Data(VISUAL_PROGRAMMING_ACTIONS.utf8), options: []) as? [String: Any] else {
            showErrorModal(message: "Failed to parse VISUAL_PROGRAMMING_ACTIONS JSON", userPrompt: userInput, jsonResponse: VISUAL_PROGRAMMING_ACTIONS)
            return
        }
        
        let body: [String: Any] = [
            "model": OPEN_AI_MODEL,
            "messages": [
                [
                    "role": "system",
                    "content": SYSTEM_PROMPT
                ],
                [
                    "role": "user",
                    "content": userInput
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "visual_programming_actions_schema",
                    "schema": responseSchema
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            showErrorModal(message: "Error encoding JSON: \(error.localizedDescription)", userPrompt: userInput, jsonResponse: nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.stitchAI.promptState.isGenerating = false
                
                if let error = error {
                    self?.showErrorModal(message: "Request error: \(error.localizedDescription)", userPrompt: userInput, jsonResponse: nil)
                    return
                }
                
                guard let data = data else {
                    self?.showErrorModal(message: "No data received", userPrompt: userInput, jsonResponse: nil)
                    return
                }
                
                
//                let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"
                
//                let s = parseJSON(jsonResponse)
//                print(s!.rawString(options: [.withoutEscapingSlashes, .prettyPrinted]))

                
                

                let jsonResponse = String(data: data, encoding: .utf8) ?? "Invalid JSON format"

                log("JSON RESPONSE")
                log(jsonResponse)
                
                if let jsonData = jsonResponse.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
                   let jsonDict = jsonObject as? [String: Any],
                   let choices = jsonDict["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let contentString = message["content"] as? String,
                   let contentData = contentString.data(using: .utf8),
                   let contentObject = try? JSONSerialization.jsonObject(with: contentData, options: []),
                   let contentDict = contentObject as? [String: Any],
                   let stepsArray = contentDict["steps"] {

                    // Wrap `stepsArray` in a dictionary to include the "steps" key
                    let stepsDict: [String: Any] = ["steps": stepsArray]

                    // I want to see us turn the OpenAI json-response into an array of our `Step` struct;
                    // right now we'er
                    
                    // Re-encode the `stepsDict` with pretty printing for readability
                    if let prettyStepsData = try? JSONSerialization.data(withJSONObject: stepsDict, options: [.prettyPrinted]),
                       let prettyStepsString = String(data: prettyStepsData, encoding: .utf8) {
                        log("STEPS PRETTY PRINTED JSON")
                        log(prettyStepsString)
                    }
                } else {
                    print("Could not parse steps")
                }
                
                do {
                    if let transformedResponse = self?.transformOpenAIResponseToLLMActionsString(data: data) {
                        guard !transformedResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            self?.showErrorModal(message: "Empty transformed response", userPrompt: userInput, jsonResponse: jsonResponse)
                            return
                        }
                        
                } catch {
                    self?.showErrorModal(message: "Error processing response: \(error.localizedDescription)", userPrompt: userInput, jsonResponse: jsonResponse)
                }
            }
        }
        task.resume()
    }
    
    
    @MainActor
    private func closeStitchAIModal() {
        self.stitchAI.promptState.showModal = false
        self.stitchAI.promptState.prompt = ""
        self.graphUI.reduxFocusedField = nil
    }
    
    func showErrorModal(message: String, userPrompt: String, jsonResponse: String?) {
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                let hostingController = UIHostingController(rootView: StitchAIErrorModalView(
                    message: message,
                    userPrompt: userPrompt,
                    jsonResponse: jsonResponse
                ))
                rootViewController.present(hostingController, animated: true, completion: nil)
            }
        }
    }
    
    func transformOpenAIResponseToLLMActionsString(data: Data) -> String? {
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let firstChoice = response.choices.first else {
                print("Invalid JSON structure: no choices available")
                return nil
            }
            
            let contentJSON = try firstChoice.message.parseContent()
            
            log("transformOpenAIResponseToLLMActionsString: contentJSON: \(contentJSON)")
            
            var llmActions: [LLMActionData] = []
            var nodeInfoMap: [String: NodeInfoData] = [:]
            var layerInputsAdded: Set<String> = []
            
            // TODO: instead of turning this
            for step in contentJSON.steps {
                guard let stepType = StepType(rawValue: step.stepType) else {
                    print("Unknown step type: \(step.stepType)")
                    continue
                }
                
                switch stepType {
                case .addNode:
                    if let nodeId = step.nodeId, let nodeName = step.nodeName {
                        
                        let parsedNodeType = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        
                        if let nodeKind = VisualProgrammingTypes.validNodeKinds[parsedNodeType.lowercased()] {
                            
                            let title = "\(nodeKind.rawValue) (\(nodeId))"
                            
                            llmActions.append(LLMActionData(action: ActionType.addNode.rawValue, node: title, nodeType: nodeKind.rawValue, port: nil, from: nil, to: nil, field: nil, value: nil))
                            
                            nodeInfoMap[nodeId] = NodeInfoData(type: nodeKind.rawValue)
                            
                        } else {
                            print("Unknown node type: '\(parsedNodeType)' does not match any validNodeTypes.")
                        }
                    }
                    
                case .addLayerInput:
                    if let nodeId = step.toNodeId, let port = step.port?.value, let nodeInfo = nodeInfoMap[nodeId], !layerInputsAdded.contains("\(nodeId):\(port)") {
                        
                        let nodeTitle = "\(nodeInfo.type.capitalized) (\(nodeId))"
                        
                        llmActions.append(LLMActionData(action: ActionType.addLayerInput.rawValue, node: nodeTitle, nodeType: nil, port: port.capitalized, from: nil, to: nil, field: nil, value: nil))
                        
                        layerInputsAdded.insert("\(nodeId):\(port)")
                    } else {
                        print("failed to add layer input)")
                    }
                case .connectNodes:
                    if let fromNodeId = step.fromNodeId, let toNodeId = step.toNodeId,
                       let fromNodeInfo = nodeInfoMap[fromNodeId], let toNodeInfo = nodeInfoMap[toNodeId] {
                        let fromNodeTitle = "\(fromNodeInfo.type.capitalized) (\(fromNodeId))"
                        let toNodeTitle = "\(toNodeInfo.type.capitalized) (\(toNodeId))"
                        
                        let portType = step.port?.value ?? toNodeInfo.type.capitalized
                        if !layerInputsAdded.contains("\(toNodeId):\(portType)") {
                            llmActions.append(LLMActionData(action: ActionType.addLayerInput.rawValue, node: toNodeTitle, nodeType: nil, port: portType.capitalized, from: nil, to: nil, field: nil, value: nil))
                            layerInputsAdded.insert("\(toNodeId):\(portType)")
                        }
                        
                        let fromEdge = EdgePoint(node: fromNodeTitle, port: "0")
                        let toEdge = EdgePoint(node: toNodeTitle, port: portType.capitalized)
                        llmActions.append(LLMActionData(action: ActionType.addEdge.rawValue, node: nil, nodeType: nil, port: nil, from: fromEdge, to: toEdge, field: nil, value: nil))
                    } else {
                        print("failed to connect nodes")
                    }
                case .changeNodeType:
                    if let nodeId = step.nodeId, let nodeTypeRaw = step.nodeType {
                        let parsedNodeType = nodeTypeRaw.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if let nodeType = VisualProgrammingTypes.validStitchAINodeTypes[parsedNodeType.capitalized] {
                            if var nodeInfo = nodeInfoMap[nodeId] {
                                let nodeTitle = "\(nodeInfo.type.capitalized) (\(nodeId))"
                                llmActions.append(LLMActionData(action: ActionType.changeNodeType.rawValue, node: nodeTitle, nodeType: nodeType.rawValue, port: nil, from: nil, to: nil, field: nil, value: nil))
                                nodeInfo.nodeType = nodeType.rawValue
                                nodeInfoMap[nodeId] = nodeInfo
                            }
                        } else {
                            print("Unrecognized value type: '\(parsedNodeType)' does not match any validValueTypes.")
                        }
                    } else {
                        print("failed to change nodes")
                    }
                    
                case .setInput:
                    if let nodeId = step.nodeId, let nodeTypeRaw = step.nodeType {
                        let parsedNodeType = nodeTypeRaw.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if let nodeType = VisualProgrammingTypes.validStitchAINodeTypes[parsedNodeType.capitalized] {
                            
                            if let value = step.value?.value {
                                if var nodeInfo = nodeInfoMap[nodeId] {
                                    let nodeTitle = "\(nodeInfo.type.capitalized) (\(nodeId))"
                                    let portNumber = String(nodeInfo.inputPortCount)
                                    let field = EdgePoint(node: nodeTitle, port: portNumber)
                                    llmActions.append(LLMActionData(action: ActionType.setInput.rawValue, node: nil, nodeType: nodeType.rawValue, port: nil, from: nil, to: nil, field: field, value: value))
                                    nodeInfo.inputPortCount += 1
                                    nodeInfoMap[nodeId] = nodeInfo
                                } else {
                                    print("failed to get nodeInfo")
                                }
                            } else {
                                print("failed to get value")
                            }
                        } else {
                            print("failed to get nodeId")
                        }
                    }
                }
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // TODO: NOV 11
            // Would be better to just return the LLMActions here?
            let jsonData = try encoder.encode(llmActions)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error transforming JSON: \(error)")
            return nil
        }
    }
}


struct OpenAIAPIKeyChanged: StitchStoreEvent {
    
    let apiKey: String
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        log("OpenAIAPIKeySet")
        
        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            apiKey,
            forKey: OPENAI_API_KEY_NAME)
        
        return .noChange
    }
}
