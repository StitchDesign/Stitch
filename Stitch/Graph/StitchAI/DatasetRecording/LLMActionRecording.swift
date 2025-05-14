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

// TODO: separate buttons (icons and actions) for generating training data vs correcting what the LLM just sent to us
struct LLMRecordingToggled: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        
        if state.llmRecording.isRecording {
            let modeLabel = state.llmRecording.mode == .augmentation ? "AUGMENTATION" : "NORMAL"
            log("📼 🛑 STOPPING LLM RECORDING MODE [\(modeLabel)] 🛑 📼")
            state.llmRecordingEnded()
        } else {
            // If we're not already recording, and we're in AI Mode,
            // then start augmentation mode
            let wasInAIMode = state.insertNodeMenuState.isFromAIGeneration
            if wasInAIMode {
                state.startLLMAugmentationMode()
            } else {
                state.llmRecordingStarted()
            }
            
            let modeLabel = state.llmRecording.mode == .augmentation ? "AUGMENTATION" : "NORMAL"
            let transitionNote = wasInAIMode ? " (Transitioned from AI Generation)" : ""
            log("📼 ▶\u{fef} STARTING LLM RECORDING MODE [\(modeLabel)]\(transitionNote) ▶\u{fef} 📼")
        }
    }
}

extension StitchDocumentViewModel {

    @MainActor
    func startLLMAugmentationMode() {
        
        log("🔄 🤖 TRANSITIONING FROM AI MODE TO RECORDING - ENTERING AUGMENTATION MODE 🤖 🔄")
        
        
        // TODO: these logs are telling us that self.llmRecording.actions is empty (we're not sure how or where they were made empty?); can we populate the actions again, before we open the "edit before submit" modal ?
        
        let derivedActions = self.deriveNewAIActions()
        self.llmRecording.actions = derivedActions
        
        // First store the current AI-generated actions
        log("🤖 💾 Storing AI-Generated Actions: \(self.llmRecording.actions)")
        
        // Invalidate the StitchAI tip -- don't need to show it to the user again
        self.stitchAITrainingTip.invalidate(reason: .actionPerformed)
        StitchAITrainingTip.hasCompletedOpenAIRequest = false
        
        // Set augmentation mode
        self.llmRecording.mode = .augmentation
        
        // Open the Edit-before-submit modal
        self.llmRecording.modal = .editBeforeSubmit
        
        // Clear the AI generation flag AFTER we've secured the actions
        self.insertNodeMenuState.isFromAIGeneration = false
        log("🔄 🤖 AI Generation Mode Cleared - Actions Preserved for Correction 🤖 🔄")
        
        // Start recording
        self.llmRecordingStarted()
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
        
        // Save initial graph entity state for tracking changes
        // MARK: only overwrite if not yet set, since AI request may have already set it
        self.llmRecording.initialGraphState = self.llmRecording.initialGraphState ?? self.visibleGraph.createSchema()
    }
    
    @MainActor
    func llmRecordingEnded() {
        let currentMode = self.llmRecording.mode
        print("📼 ⚡\u{fef} LLM Recording Ended - isRecording set to false ⚡\u{fef} 📼")
        print("🎯 Current Recording Mode: \(currentMode)")
        self.llmRecording.isRecording = false
        
        // Debug print all actions
//        print("🤖 Complete Action Sequence: \(self.llmRecording.actions.asJSONDisplay())")
        
        // Cache the json of all actions
        self.llmRecording.promptState.actionsAsDisplayString = self.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions
        if !self.llmRecording.actions.isEmpty {
            if currentMode == .augmentation {
                print("📼 🤖 Augmentation mode - Skipping prompt modal and proceeding to save 🤖 📼")
                self.closedLLMRecordingPrompt()
            } else if !self.llmRecording.hasShownModalInNormalMode {
                print("📼 📝 Opening LLM Recording Prompt Modal 📝 📼")
                self.llmRecording.promptState.showModal = true
                self.llmRecording.hasShownModalInNormalMode = true
                self.reduxFocusedField = .llmRecordingModal
            }
        }
    }
    
    @MainActor func closedLLMRecordingPrompt() {
        let currentMode = self.llmRecording.mode
        log("📼 💾 Closing LLM Recording Prompt - Saving Data 💾 📼")
        log("🎯 Current Mode for Upload: \(currentMode)")
        
        self.llmRecording.promptState.showModal = false
        self.reduxFocusedField = nil
        
        let actions = self.llmRecording.actions
        
        guard !actions.isEmpty else {
            log("📼 ⚠️ No actions to save - Resetting recording state ⚠️ 📼")
            self.llmRecording = .init()
            return
        }
        
        self.showLLMEditModal()
    }
}
