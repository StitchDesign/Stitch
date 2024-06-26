//
//  LLMEvents.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftyJSON
import StitchSchemaKit

// Redux-events associated with LLM recording etc.

struct LLMRecordingToggled: GraphEvent {
    
    func handle(state: GraphState) {
        if state.graphUI.llmRecording.isRecording {
            state.llmRecordingEnded()
        } else {
            state.llmRecordingStarted()
        }
    }
}

extension GraphState {
    
    @MainActor
    func llmRecordingStarted() {
        self.graphUI.llmRecording.isRecording = true
        
        // Jump back to center, so the LLMMoveNde.position can be diff'd against 0,0
        self.graphMovement.localPosition = .zero
        self.graphMovement.localPreviousPosition = .zero
    }
    
    @MainActor
    func llmRecordingEnded() {
        self.graphUI.llmRecording.isRecording = false
        
        // Cache the json of the actions; else TextField changes cause constant encoding and thus json-order changes
        self.graphUI.llmRecording.promptState.actionsAsDisplayString = self.graphUI.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions, show the prompt
        if !self.graphUI.llmRecording.actions.isEmpty {
            self.graphUI.llmRecording.promptState.showPromptModal = true
        }
    }
}

struct LLMActionsJSONEntryModalOpened: GraphUIEvent {
    func handle(state: GraphUIState) {
        state.llmRecording.jsonEntryState.showModal = true
    }
}

// When json-entry modal is closed, we turn the JSON of LLMActions into state changes
struct LLMActionsJSONEntryModalClosed: GraphEventWithResponse {
    func handle(state: GraphState) -> GraphResponse {
        
        state.graphUI.llmRecording.jsonEntryState.showModal = false
        let jsonEntry = state.graphUI.llmRecording.jsonEntryState.jsonEntry
        state.graphUI.llmRecording.jsonEntryState.jsonEntry = ""
        
        do {
            let json = JSON(parseJSON: jsonEntry) // returns null json if parsing fails
            let data = try json.rawData()
            let actions: LLMActions = try JSONDecoder().decode(LLMActions.self,
                                                               from: data)
            actions.forEach { state.handleLLMAction($0) }
            state.graphUI.llmRecording.jsonEntryState = .init() // reset
            return .shouldPersist
        } catch {
            log("LLMActionsJSONEntryModalClosed: Error: \(error)")
            fatalErrorIfDebug("LLMActionsJSONEntryModalClosed: could not retieve ")
            return .noChange
        }
    }
}

extension String {
            
    // e.g. for llm node title = "Power (123456)",
    // llm node id is "123456"
    // llm node kind is "Power"
    var parseLLMNodeTitle: (String, NodeKind)? {
        
        var s = self
        
        // drop closing parens
        s.removeLast()
        
        // split at and remove opening parens
        var _s = s.split(separator: "(")
        
        let llmNodeId = (_s.last ?? "").trimmingCharacters(in: .whitespaces)
        let llmNodeKind = (_s.first ?? "").trimmingCharacters(in: .whitespaces).getNodeKind
        
        if let llmNodeKind = llmNodeKind {
            return (llmNodeId, llmNodeKind)
        } else {
            log("parseLLMNodeTitle: unable to parse LLM Node Title")
            return nil
        }
    }
    
    var getNodeKind: NodeKind? {
        // Assumes `self` is already "human-readable" patch/layer name,
        // e.g. "Convert Position" not "convertPosition"
        // TODO: update Patch and Layer enums to use human-readable names for their cases' raw string values; then can just use `Patch(rawValue: self)`
        if let layer = Layer.allCases.first(where: { $0.defaultDisplayTitle() == self }) {
            return .layer(layer)
        } else if let patch = Patch.allCases.first(where: { $0.defaultDisplayTitle() == self }) {
            return .patch(patch)
        }
        
        return nil
    }
}
     
typealias LLMNodeTitleIdToNodeId = [String: NodeId]

extension GraphState {
    
    @MainActor
    func handleLLMAction(_ action: LLMAction) {
        
        log("handleLLMAction: action: \(action)")
        
        switch action {
            
        case .addNode(let llmAddNode):
            // AddNode action has a specific "LLM action node id" i.e. node default title + part of the node id
            // ... suppose we create a node, then move it;
            // the LLM-move-action will expect the specific "LLM action
            
            if let (llmNodeId, nodeKind) = llmAddNode.node.parseLLMNodeTitle,
               let nodeId = self.nodeCreated(choice: nodeKind) {
                self.graphUI
                    .llmRecording
                    .jsonEntryState
                    .llmNodeIdMapping.updateValue(nodeId, forKey: llmNodeId)
            }
            
        case .moveNode(let llmMoveNode):
            <#code#>
            
        case .addEdge(let llmAddEdge):
            <#code#>
        case .setField(let llmSetFieldAction):
            <#code#>
        case .changeNodeType(let llmAChangeNodeTypeAction):
            <#code#>
        case .addLayerInput(let llmAddLayerInput):
            <#code#>
        case .addLayerOutput(let llmAddLayerOutput):
            <#code#>
        }
    }
}

// When prompt modal is closed, we write the JSON of prompt + actions to file.
struct LLMRecordingPromptClosed: GraphEvent {

    func handle(state: GraphState) {
        
        // log("LLMRecordingPromptClosed called")
        
        state.graphUI.llmRecording.promptState.showPromptModal = false
        
        let actions = state.graphUI.llmRecording.actions
        
        // TODO: somehow we're getting this called twice
        guard !actions.isEmpty else {
            state.graphUI.llmRecording = .init()
            return
        }
        
        // Write the JSONL/YAML to file
        let recordedData = LLMRecordingData(actions: actions,
                                            prompt: state.graphUI.llmRecording.promptState.prompt)
        
        // log("LLMRecordingPromptClosed: recordedData: \(recordedData)")
        
        if !recordedData.actions.isEmpty {
            Task {
                do {
                    let data = try JSONEncoder().encode(recordedData)
                    
                    // need to create a directory
                    let docsURL = StitchFileManager.documentsURL.url
                    let dataCollectionURL = docsURL.appendingPathComponent(LLM_COLLECTION_DIRECTORY)
                    let filename = "\(state.projectName)_\(state.projectId)_\(Date().description).json"
                    let url = dataCollectionURL.appending(path: filename)
                    
                    // log("LLMRecordingPromptClosed: docsURL: \(docsURL)")
                    // log("LLMRecordingPromptClosed: dataCollectionURL: \(dataCollectionURL)")
                    // log("LLMRecordingPromptClosed: url: \(url)")
                    
                    // It's okay if this fails because directory already exists
                    try? FileManager.default.createDirectory(
                        at: dataCollectionURL,
                        withIntermediateDirectories: false)
                    
                    try data.write(to: url,
                                   options: [.atomic, .completeFileProtection])
                    
                    // DEBUG
                    // let input = try String(contentsOf: url)
                    // log("LLMRecordingPromptClosed: success: \(input)")
                } catch {
                     log("LLMRecordingPromptClosed: error: \(error.localizedDescription)")
                }
            }
        }
        
        // Reset LLMRecordingState
        state.graphUI.llmRecording = .init()
    }
}

struct LLMRecordingModeEnabledChanged: StitchStoreEvent {
    
    let enabled: Bool
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        log("LLMRecordingModeSet: enabled: \(enabled)")
        store.llmRecordingModeEnabled = enabled
        
        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            enabled,
            forKey: LLM_RECORDING_MODE_KEY_NAME)
        
        return .noChange
    }
}
