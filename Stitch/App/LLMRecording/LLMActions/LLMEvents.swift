//
//  LLMEvents.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation

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
        self.graphUI.llmRecording.actionsAsDisplayString = self.graphUI.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions, show the prompt
        if !self.graphUI.llmRecording.actions.isEmpty {
            self.graphUI.llmRecording.showPromptModal = true
        }
    }
}


struct LLMRecordingPromptClosed: GraphEvent {

    func handle(state: GraphState) {
        
        // log("LLMRecordingPromptClosed called")
        
        state.graphUI.llmRecording.showPromptModal = false
        
        let actions = state.graphUI.llmRecording.actions
        
        // TODO: somehow we're getting this called twice
        guard !actions.isEmpty else {
            state.graphUI.llmRecording = .init()
            return
        }
        
        // Write the JSONL/YAML to file
        let recordedData = LLMRecordingData(actions: actions,
                                            prompt: state.graphUI.llmRecording.prompt)
        
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
                    
                    let input = try String(contentsOf: url)
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
