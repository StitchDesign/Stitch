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
    
    @MainActor
    func openedStitchAIModal() {
        self.stitchAI.promptState.showModal = true
        self.graphUI.reduxFocusedField = .stitchAIPromptModal
    }
    
    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor
    func closedStitchAIModal() {
        let prompt = self.stitchAI.promptState.prompt
        
        self.stitchAI.promptState.showModal = false
        self.graphUI.reduxFocusedField = nil
        
        // HACK until we figure out why this is called twice
        if prompt == "" {
            return
        }

        // Only submit API request via 'submit'
        // dispatch(MakeOpenAIRequest(prompt: prompt))

        self.stitchAI.promptState.prompt = ""
    }
    
    @MainActor
    func closeStitchAIModal() {
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
            
    // TODO: NO LONGER USED
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
