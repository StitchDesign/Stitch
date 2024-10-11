//
//  StitchAIEvents.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation
import SwiftUI

extension StitchDocumentViewModel {

    @MainActor func openedStitchAIModal() {
        self.stitchAI.promptEntryState.showModal = true
        self.graphUI.reduxFocusedField = .stitchAIPromptModal
    }

    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor func closedStitchAIModal() {
        let prompt = self.stitchAI.promptEntryState.prompt
        
        self.stitchAI.promptEntryState.showModal = false
        self.stitchAI.promptEntryState.prompt = ""
        self.graphUI.reduxFocusedField = nil
 
        makeAPIRequest(userInput: prompt)
        self.stitchAI.promptEntryState.prompt = ""

    }
    
    func makeAPIRequest(userInput: String) {
        let openAIAPIURL = URL(string: OPEN_AI_BASE_URL)!
        var request = URLRequest(url: openAIAPIURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = UserDefaults.standard.string(forKey: OPENAI_API_KEY_NAME) {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            // Parse the VISUAL_PROGRAMMING_ACTIONS schema
            let responseSchema: [String: Any]
            do {
                if let data = VISUAL_PROGRAMMING_ACTIONS.data(using: .utf8) {
                    responseSchema = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
                } else {
                    print("Failed to convert VISUAL_PROGRAMMING_ACTIONS to Data")
                    return
                }
            } catch {
                print("Error parsing VISUAL_PROGRAMMING_ACTIONS JSON: \(error)")
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
                print("Error encoding JSON: \(error)")
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { [self] data, response, error in
                if let error = error {
                    print("Error making request: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                // Print the raw JSON response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON Response: \(jsonString)")
                } else {
                    print("Failed to convert data to string.")
                }
                
                
                do {
                    let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    
                    // Convert the OpenAIResponse object to JSON Data
                    let jsonData = try JSONEncoder().encode(openAIResponse)
                    
                    // Convert JSON Data to a pretty-printed string
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                    // Access steps
                } catch {
                    print("Error decoding JSON: \(error)")
                }
                
                
                if let transformedResponse = transformOpenAIResponseToLLMActionsString(data: data) {
                    
                    DispatchQueue.main.async {
                        dispatch(LLMJsonEdited(jsonEntry: transformedResponse))
                    }
                } else {
                    print("Error transforming response to LLM Actions string")
                }
            }
            task.resume()
        } else {
            print("No API Key found")
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
            var llmActions: [LLMActionTest] = []
            var nodeInfoMap: [String: NodeInfoTest] = [:]
            var layerInputsAdded: Set<String> = []
            
            for step in contentJSON.steps {
                guard let stepType = StepType(rawValue: step.stepType) else {
                    print("Unknown step type: \(step.stepType)")
                    continue
                }
                
                switch stepType {
                case .addNode:
                    if let nodeId = step.nodeId, let nodeName = step.nodeName {
                        let parsedNodeType = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if let nodeType = VisualProgrammingTypes.validNodeTypes[parsedNodeType.lowercased()] {
                            let title = "\(nodeType.rawValue) (\(nodeId))"
                            llmActions.append(LLMActionTest(action: ActionType.addNode.rawValue, node: title, nodeType: nodeType.rawValue, port: nil, from: nil, to: nil, field: nil, value: nil))
                            nodeInfoMap[nodeId] = NodeInfoTest(type: nodeType.rawValue)
                        } else {
                            print("Unknown node type: '\(parsedNodeType)' does not match any validNodeTypes.")
                        }
                    }
                    
                case .addLayerInput:
                    if let nodeId = step.toNodeId, let port = step.port?.value, let nodeInfo = nodeInfoMap[nodeId], !layerInputsAdded.contains("\(nodeId):\(port)") {
                        let nodeTitle = "\(nodeInfo.type.capitalized) (\(nodeId))"
                        llmActions.append(LLMActionTest(action: ActionType.addLayerInput.rawValue, node: nodeTitle, nodeType: nil, port: port.capitalized, from: nil, to: nil, field: nil, value: nil))
                        layerInputsAdded.insert("\(nodeId):\(port)")
                    }
                case .connectNodes:
                    if let fromNodeId = step.fromNodeId, let toNodeId = step.toNodeId,
                       let fromNodeInfo = nodeInfoMap[fromNodeId], let toNodeInfo = nodeInfoMap[toNodeId] {
                        let fromNodeTitle = "\(fromNodeInfo.type.capitalized) (\(fromNodeId))"
                        let toNodeTitle = "\(toNodeInfo.type.capitalized) (\(toNodeId))"
                        
                        let portType = step.port?.value ?? toNodeInfo.type.capitalized
                        if !layerInputsAdded.contains("\(toNodeId):\(portType)") {
                            llmActions.append(LLMActionTest(action: ActionType.addLayerInput.rawValue, node: toNodeTitle, nodeType: nil, port: portType.capitalized, from: nil, to: nil, field: nil, value: nil))
                            layerInputsAdded.insert("\(toNodeId):\(portType)")
                        }
                        
                        let fromEdge = EdgePoint(node: fromNodeTitle, port: "0")
                        let toEdge = EdgePoint(node: toNodeTitle, port: portType.capitalized)
                        llmActions.append(LLMActionTest(action: ActionType.addEdge.rawValue, node: nil, nodeType: nil, port: nil, from: fromEdge, to: toEdge, field: nil, value: nil))
                    }
                case .changeNodeType:
                    if let nodeId = step.nodeId, let nodeTypeRaw = step.valueType {
                        let parsedNodeType = nodeTypeRaw.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if let valueType = VisualProgrammingTypes.validValueTypes[parsedNodeType.lowercased()], var nodeInfo = nodeInfoMap[nodeId] {
                            let nodeTitle = "\(nodeInfo.type.capitalized) (\(nodeId))"
                            llmActions.append(LLMActionTest(action: ActionType.changeNodeType.rawValue, node: nodeTitle, nodeType: valueType.rawValue, port: nil, from: nil, to: nil, field: nil, value: nil))
                            nodeInfo.valueType = valueType.rawValue
                            nodeInfoMap[nodeId] = nodeInfo
                        } else {
                            print("Unrecognized value type: '\(parsedNodeType)' does not match any validValueTypes.")
                        }
                    }
                    
                case .setInput:
                    if let nodeId = step.nodeId, let value = step.value?.value, var nodeInfo = nodeInfoMap[nodeId] {
                        let nodeTitle = "\(nodeInfo.type.capitalized) (\(nodeId))"
                        let portNumber = String(nodeInfo.inputPortCount)
                        let field = EdgePoint(node: nodeTitle, port: portNumber)
                        llmActions.append(LLMActionTest(action: ActionType.setInput.rawValue, node: nil, nodeType: nodeInfo.valueType?.uppercased(), port: nil, from: nil, to: nil, field: field, value: value))
                        nodeInfo.inputPortCount += 1
                        nodeInfoMap[nodeId] = nodeInfo
                    }
                }
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
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
