//
//  LLMActionRecording.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/27/24.
//

import Foundation
import StitchSchemaKit

extension StitchDocumentViewModel {

    @MainActor
    func startLLMAugmentationMode() {

        log("🔄 🤖 ENTERING AUGMENTATION MODE 🤖 🔄")
        log("🤖 💾 AI-Generated Actions: \(self.llmRecording.actions)")
        
        // Invalidate the StitchAI tip -- don't need to show it to the user again
        self.stitchAITrainingTip.invalidate(reason: .actionPerformed)
        StitchAITrainingTip.hasCompletedOpenAIRequest = false
        
        self.showEditBeforeSubmitModal()
    }
    
    // Note: in some cases we want to show the edit-before-submit modal even though we're not correcting a response from OpenAI
    @MainActor
    func showEditBeforeSubmitModal() {
        // We should never enter edit-before-submit modal if we don't have actions
        assertInDebug(!self.llmRecording.actions.isEmpty)
        
        // Open the Edit-before-submit modal
        self.llmRecording.modal = .editBeforeSubmit
        
        // Clear the AI generation flag AFTER we've secured the actions
        self.insertNodeMenuState.isFromAIGeneration = false
        log("🔄 🤖 AI Generation Mode Cleared - Actions Preserved for Correction 🤖 🔄")
        
        // Start recording (so we pick up graph changes as new actions etc.)
        self.llmRecordingStarted()
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func llmRecordingStarted() {
        print("📼 ⚡️ LLM Recording Started - isRecording set to true ⚡️ 📼")
        
        // Save initial graph entity state for tracking changes
        // MARK: only overwrite if not yet set, since AI request may have already set it
        self.llmRecording.initialGraphState = self.llmRecording.initialGraphState ?? self.visibleGraph.createSchema()
    }
    
    @MainActor
    func llmRecordingEnded() {
        print("📼 ⚡\u{fef} LLM Recording Ended - isRecording set to false ⚡\u{fef} 📼")
        
        // If we stopped recording and have LLMActions
        if !self.llmRecording.actions.isEmpty {
            print("📼 🤖 Augmentation mode - Skipping prompt modal and proceeding to save 🤖 📼")
            self.closedLLMRecordingPrompt()
        }
    }
    
    @MainActor func closedLLMRecordingPrompt() {
        log("📼 💾 Closing LLM Recording Prompt - Saving Data 💾 📼")
        
        self.llmRecording.modal = .none
        self.reduxFocusedField = nil
        
        let actions = self.llmRecording.actions
        
        guard !actions.isEmpty else {
            log("📼 ⚠️ No actions to save - Resetting recording state ⚠️ 📼")
            self.llmRecording = .init()
            return
        }
        
        self.showEditBeforeSubmitModal()
    }
}
