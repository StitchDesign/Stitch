//
//  LLMActionRecording.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/27/24.
//

import Foundation
import StitchSchemaKit


// MARK: recording user's actions in app as a JSON of LLM Step Actions, assigning a natural language prompt and writing JSON + prompt to file

let LLM_START_RECORDING_SF_SYMBOL = "inset.filled.rectangle.badge.record"
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
            // First store the current AI-generated actions
            let currentActions = document.lastAIGeneratedActions
            print("🤖 💾 Storing AI-Generated Actions: \(currentActions)")
            
            // Set augmentation mode
            document.llmRecording.mode = .augmentation
            
            // We keep the actions as they are - don't clear them
            print("🤖 💾 Verified Actions Count: \(currentActions.count)")
            print("🤖 💾 Verified Actions Content: \(currentActions.asJSONDisplay())")
            
            // Clear the AI generation flag AFTER we've secured the actions
            state.graphUI.insertNodeMenuState.isFromAIGeneration = false
            print("🔄 🤖 AI Generation Mode Cleared - Actions Preserved for Correction 🤖 🔄")
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
    let prompt: String
}

extension StitchDocumentViewModel {
    
    @MainActor
    func llmRecordingStarted() {
        print("📼 ⚡️ LLM Recording Started - isRecording set to true ⚡️ 📼")
        print("🎯 Current Recording Mode: \(self.llmRecording.mode)")
        
        // Debug print current actions before starting recording
//        print("🤖 Current Actions at Recording Start: \(self.llmRecording.actions.asJSONDisplay())")
        
        self.llmRecording.isRecording = true
    }
    
    @MainActor
    func llmRecordingEnded() {
        let currentMode = self.llmRecording.mode
        print("📼 ⚡\u{fef} LLM Recording Ended - isRecording set to false ⚡\u{fef} 📼")
        print("🎯 Current Recording Mode: \(currentMode)")
        self.llmRecording.isRecording = false
        
        // Debug print all actions
        print("🤖 Complete Action Sequence: \(self.llmRecording.actions.asJSONDisplay())")
        
        // Cache the json of all actions
        self.llmRecording.promptState.actionsAsDisplayString = self.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions
        if !self.llmRecording.actions.isEmpty {
            if currentMode == .augmentation {
                print("📼 🤖 Augmentation mode - Skipping prompt modal and proceeding to save 🤖 📼")
                self.closedLLMRecordingPrompt()
            } else {
                print("📼 📝 Opening LLM Recording Prompt Modal 📝 📼")
                self.llmRecording.promptState.showModal = true
                self.graphUI.reduxFocusedField = .llmRecordingModal
            }
        }
    }
    
    // When prompt modal is closed, we write the JSON of prompt + actions to file.
    @MainActor func closedLLMRecordingPrompt() {
        let currentMode = self.llmRecording.mode
        print("📼 💾 Closing LLM Recording Prompt - Saving Data 💾 📼")
        print("🎯 Current Mode for Upload: \(currentMode)")
        
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
                    // Store the mode before reset
                    let isAugmentation = currentMode == .augmentation
                    
                    // Upload with current mode
                    try await SupabaseManager.shared.uploadLLMRecording(
                        recordedData, graphState: graph,
                        isCorrection: isAugmentation
                    )
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
        // Reset the recording state after upload is complete
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
