//
//  LLMActionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/27/25.
//

import Foundation

// WE CANCELLED THE WHOLE THING
struct LLMAugmentationCancelled: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMAugmentationCancelled called")
        state.llmRecording = .init()
    }
}

struct ShowLLMApprovalModal: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("ShowLLMApprovalModal called")
        
        // Skip approval UI for normal mode
        if state.llmRecording.mode == .normal {
            // Directly submit to Supabase
            dispatch(SubmitLLMActionsToSupabase())
            return
        }
        
        // End recording when we open the final submit
        state.llmRecordingEnded()
        
        // Show modal
        state.llmRecording.modal = .approveAndSubmit
    }
}

struct ShowLLMEditModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("ShowLLMEditModal called")
        state.showLLMEditModal()
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func showLLMEditModal() {
        self.llmRecording.isRecording = true
        
        //       Always treat edit modal as an augmentation
        self.llmRecording.mode = .augmentation
        
        self.llmRecording.modal = .editBeforeSubmit
    }
}

struct SubmitLLMActionsToSupabase: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("SubmitLLMActionsToSupabase called")
        
        guard let supabaseManager = state.aiManager else {
            log("SubmitLLMActionsToSupabase error: no supabase")
            return
        }
        
        do {
            log("📼 ⬆️ Uploading recording data to Supabase ⬆️ 📼")
            
            // TODO: JAN 25: these should be from the edited whatever...
            let actionsAsSteps = state.llmRecording.actions
            log("ShowLLMApprovalModal: actions: \(actionsAsSteps)")
            
            guard let deviceUUID = try StitchAIManager.getDeviceUUID() else {
                log("SubmitLLMActionsToSupabase error: no device ID found.")
                return
            }
            
            Task { [weak supabaseManager] in
                try await supabaseManager?.uploadEditedActions(
                    prompt: state.llmRecording.promptState.prompt,
                    finalActions: actionsAsSteps,
                    deviceUUID: deviceUUID,
                    isCorrection: state.llmRecording.mode == .augmentation)
                
                log("📼 ✅ Data successfully saved locally and uploaded to Supabase ✅ 📼")
                state.llmRecording = .init()
            }
            
        } catch let encodingError as EncodingError {
            log("📼 ❌ Encoding error: \(encodingError.localizedDescription) ❌ 📼")
            state.llmRecording = .init()
        } catch let fileError as NSError {
            log("📼 ❌ File system error: \(fileError.localizedDescription) ❌ 📼")
            state.llmRecording = .init()
        } catch {
            log("📼 ❌ Error: \(error.localizedDescription) ❌ 📼")
            state.llmRecording = .init()
        }
    }
}

struct LLMActionDeleted: StitchDocumentEvent {
    let deletedAction: Step
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMActionDeleted: deletedAction: \(deletedAction)")
        log("LLMActionDeleted: state.llmRecording.actions was: \(state.llmRecording.actions)")
        
        guard let deletedAction = state.llmRecording.actions.first(where: {
            $0 == deletedAction
        }) else {
            fatalErrorIfDebug()
            return
        }
                
        do {
            // Run deletion process for action
            try deletedAction.convertToType().removeAction(graph: state.visibleGraph)
            
            // Filter out removed action before re-applying actions
            let filteredActions = state.llmRecording.actions.filter { $0 != deletedAction }
            
            state.llmRecording.actions = filteredActions

            // If we deleted the LLMAction that added a patch to the graph,
            // then we should also delete any LLMActions that e.g. changed that patch's nodeType or inputs.
            
            // We immediately "de-apply" the removed action(s) from graph,
            // so that user instantly sees what changed.
            try state.reapplyActions()
        } catch {
            log("LLMActionDeleted: when reapplying actions, encountered: \(error)")
        }
    }
}
