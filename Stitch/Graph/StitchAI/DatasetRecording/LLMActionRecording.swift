//
//  LLMActionRecording.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/27/24.
//

import Foundation
import StitchSchemaKit


// MARK: recording user's actions in app as a JSON of LLM Step Actions, assigning a natural language prompt and writing JSON + prompt to file

let LLM_START_RECORDING_SF_SYMBOL = "play.fill"
let LLM_STOP_RECORDING_SF_SYMBOL = "stop.fill"

struct LLMRecordingToggled: GraphEvent {
    
    func handle(state: GraphState) {
        guard let document = state.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let wasInAIMode = state.graphUI.insertNodeMenuState.isFromAIGeneration
        
        // Check if we're transitioning from AI generation to recording
        if wasInAIMode {
            print("🔄 🤖 TRANSITIONING FROM AI MODE TO RECORDING - ENTERING AUGMENTATION MODE 🤖 🔄")
            // Changed: Store actions before clearing AI generation state
            let currentActions = document.llmRecording.actions
            document.llmRecording.mode = .augmentation
            document.llmRecording.lastAIGeneratedActions = currentActions.asJSONDisplay()
            print("🤖 💾 Generated Actions: \(document.llmRecording.lastAIGeneratedActions) 💾 🤖")
            
            // Clear the AI generation flag since we're now in recording mode
            state.graphUI.insertNodeMenuState.isFromAIGeneration = false
            print("🔄 🤖 AI Generation Mode Cleared - Now in Recording Mode 🤖 🔄")
        }
        
        if document.llmRecording.isRecording {
            let modeLabel = document.llmRecording.mode == .augmentation ? "AUGMENTATION" : "NORMAL"
            print("📼 🛑 STOPPING LLM RECORDING MODE [\(modeLabel)] 🛑 📼")
            document.llmRecordingEnded()
        } else {
            let modeLabel = document.llmRecording.mode == .augmentation ? "AUGMENTATION" : "NORMAL"
            let transitionNote = wasInAIMode ? " (Transitioned from AI Generation)" : ""
            print("📼 ▶\u{fef} STARTING LLM RECORDING MODE [\(modeLabel)]\(transitionNote) ▶\u{fef} 📼")
            document.llmRecordingStarted()
        }
    }
}

/// What we write to JSON/JSONL file
struct LLMRecordingData: Equatable, Encodable {
    let actions: LLMStepActions
    let prompt: String // user-entered
}

extension StitchDocumentViewModel {
    
    @MainActor
    func llmRecordingStarted() {
        print("📼 ⚡️ LLM Recording Started - isRecording set to true ⚡️ 📼")
        
        // Added: Debug print current actions before starting recording
        print("🤖 Current Actions at Recording Start: \(self.llmRecording.actions.asJSONDisplay())")
        
        self.llmRecording.isRecording = true
    }
    
    @MainActor
    func llmRecordingEnded() {
        print("📼 ⚡️ LLM Recording Ended - isRecording set to false ⚡️ 📼")
        self.llmRecording.isRecording = false
        
        // Added: Debug print actions before caching
        print("🤖 Current Actions at Recording End: \(self.llmRecording.actions.asJSONDisplay())")
        
        // Cache the json of the actions; else TextField changes cause constant encoding and thus json-order changes
        self.llmRecording.promptState.actionsAsDisplayString = self.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions, show the prompt
        if !self.llmRecording.actions.isEmpty {
            print("📼 📝 Opening LLM Recording Prompt Modal 📝 📼")
            self.llmRecording.promptState.showModal = true
            self.graphUI.reduxFocusedField = .llmRecordingModal
        }
    }
    
    // When prompt modal is closed, we write the JSON of prompt + actions to file.
    @MainActor func closedLLMRecordingPrompt() {
        print("📼 💾 Closing LLM Recording Prompt - Saving Data 💾 📼")
        
        self.llmRecording.promptState.showModal = false
        self.graphUI.reduxFocusedField = nil
        
        let actions = self.llmRecording.actions
        
        guard !actions.isEmpty else {
            print("📼 ⚠️ No actions to save - Resetting recording state ⚠️ 📼")
            self.llmRecording = .init()
            return
        }
        
        // Write the JSONL/YAML to file
        let recordedData = LLMRecordingData(actions: actions,
                                            prompt: self.llmRecording.promptState.prompt)
        
        if !recordedData.actions.isEmpty {
            Task {
                do {
                    let data = try JSONEncoder().encode(recordedData)
                    
                    let docsURL = StitchFileManager.documentsURL
                    let dataCollectionURL = docsURL.appendingPathComponent(LLM_COLLECTION_DIRECTORY)
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let formattedDate = dateFormatter.string(from: Date())
                    let filename = "\(self.graph.name)_\(self.graph.id)_\(formattedDate).json"
                    let url = dataCollectionURL.appendingPathComponent(filename)
                    
                    if !FileManager.default.fileExists(atPath: dataCollectionURL.path) {
                        try FileManager.default.createDirectory(
                            at: dataCollectionURL,
                            withIntermediateDirectories: true)
                    }
                    
                    try data.write(to: url, options: [.atomic, .completeFileProtection])
                    
                    print("📼 ⬆️ Uploading recording data to Supabase ⬆️ 📼")
                    try await SupabaseManager.shared.uploadLLMRecording(recordedData)
                    print("📼 ✅ Data successfully saved locally and uploaded to Supabase ✅ 📼")
                    
                } catch let encodingError as EncodingError {
                    print("📼 ❌ Encoding error: \(encodingError.localizedDescription) ❌ 📼")
                } catch let fileError as NSError {
                    print("📼 ❌ File system error: \(fileError.localizedDescription) ❌ 📼")
                } catch {
                    print("📼 ❌ Error: \(error.localizedDescription) ❌ 📼")
                }
            }
        }
    
        print("📼 🔄 Resetting LLM Recording State 🔄 📼")
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
