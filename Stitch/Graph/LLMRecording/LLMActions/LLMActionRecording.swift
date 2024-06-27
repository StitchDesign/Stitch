//
//  LLMActionRecording.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/27/24.
//

import Foundation
import StitchSchemaKit


// MARK: recording user's actions in app as a JSON of LLM Actions, assigning a natural language prompt and writing JSON + prompt to file

let LLM_START_RECORDING_SF_SYMBOL = "play.fill"
let LLM_STOP_RECORDING_SF_SYMBOL = "stop.fill"


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
            self.graphUI.llmRecording.promptState.showModal = true
            self.graphUI.reduxFocusedField = .llmModal
        }
    }
}

// When prompt modal is closed, we write the JSON of prompt + actions to file.
struct LLMRecordingPromptClosed: GraphEvent {
    
    func handle(state: GraphState) {
        
        // log("LLMRecordingPromptClosed called")
        
        state.graphUI.llmRecording.promptState.showModal = false
        state.graphUI.reduxFocusedField = nil
        
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
