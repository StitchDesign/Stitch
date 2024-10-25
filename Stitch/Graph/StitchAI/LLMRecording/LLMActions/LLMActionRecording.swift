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
        guard let document = state.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        if document.llmRecording.isRecording {
            document.llmRecordingEnded()
        } else {
            document.llmRecordingStarted()
        }
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func llmRecordingStarted() {
        self.llmRecording.isRecording = true
        
        // Jump back to center, so the LLMMoveNde.position can be diff'd against 0,0
        self.graphMovement.localPosition = .zero
        self.graphMovement.localPreviousPosition = .zero
    }
    
    @MainActor
    func llmRecordingEnded() {
        self.llmRecording.isRecording = false
        
        // Cache the json of the actions; else TextField changes cause constant encoding and thus json-order changes
        self.llmRecording.promptState.actionsAsDisplayString = self.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions, show the prompt
        if !self.llmRecording.actions.isEmpty {
            self.llmRecording.promptState.showModal = true
            self.graphUI.reduxFocusedField = .llmRecordingModal
        }
    }
    
    // When prompt modal is closed, we write the JSON of prompt + actions to file.
    @MainActor func closedLLMRecordingPrompt() {
        
        // log("LLMRecordingPromptClosed called")
        
        self.llmRecording.promptState.showModal = false
        self.graphUI.reduxFocusedField = nil
        
        let actions = self.llmRecording.actions
        
        // TODO: somehow we're getting this called twice
        guard !actions.isEmpty else {
            self.llmRecording = .init()
            return
        }
        
        // Write the JSONL/YAML to file
        let recordedData = LLMRecordingData(actions: actions,
                                            prompt: self.llmRecording.promptState.prompt)
        
        // log("LLMRecordingPromptClosed: recordedData: \(recordedData)")
        
        if !recordedData.actions.isEmpty {
            Task {
                do {
                    let data = try JSONEncoder().encode(recordedData)
                    
                    // need to create a directory
                    let docsURL = StitchFileManager.documentsURL
                    let dataCollectionURL = docsURL.appendingPathComponent(LLM_COLLECTION_DIRECTORY)
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let formattedDate = dateFormatter.string(from: Date())
                    let filename = "\(self.graph.name)_\(self.graph.id)_\(formattedDate).json"
                    // log("LLMRecordingPromptClosed: docsURL: \(docsURL)")
                    // log("LLMRecordingPromptClosed: dataCollectionURL: \(dataCollectionURL)")
                    // log("LLMRecordingPromptClosed: url: \(url)")
                    let url = dataCollectionURL.appendingPathComponent(filename)
                    
                    // Ensure the directory exists
                    if !FileManager.default.fileExists(atPath: dataCollectionURL.path) {
                        try FileManager.default.createDirectory(
                            at: dataCollectionURL,
                            withIntermediateDirectories: true)
                    }
                    
                    try data.write(to: url, options: [.atomic, .completeFileProtection])
                    
                    // DEBUG
                    // let input = try String(contentsOf: url)
                    // log("LLMRecordingPromptClosed: success: \(input)")
                    log("LLMRecordingPromptClosed: Data successfully saved to: \(url.path)")
                } catch let encodingError as EncodingError {
                    log("LLMRecordingPromptClosed: Encoding error: \(encodingError.localizedDescription)")
                } catch let fileError as NSError {
                    log("LLMRecordingPromptClosed: File system error: \(fileError.localizedDescription)")
                } catch {
                    log("LLMRecordingPromptClosed: error: \(error.localizedDescription)")
                }
            }
        }
    
        
        // Reset LLMRecordingState
        self.llmRecording = .init()
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
