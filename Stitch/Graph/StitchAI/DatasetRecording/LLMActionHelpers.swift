//
//  LLMActionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/27/25.
//

import Foundation


struct StitchAIActionReviewCancelled: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("StitchAIActionReviewCancelled called")
        state.llmRecording = .init()
    }
}

struct ShowApproveAndSubmitModal: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("ShowApproveAndSubmitModal called")
        
        switch state.llmRecording.mode {
        
        case .normal:
            // Directly submit to Supabase
            state.submitApprovedActionsToSupabase()
            return
        
        case .augmentation:
            // End recording when we open the final submit
            state.llmRecordingEnded()
            
            // Show modal
            state.llmRecording.modal = .approveAndSubmit
        }
    }
}

struct ShowEditBeforeSubmitModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("ShowEditBeforeSubmitModal called")
        state.showEditBeforeSubmitModal()
    }
}

struct ActionsApprovedAndSubmittedToSupabase: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.submitApprovedActionsToSupabase()
    }
}

extension StitchDocumentViewModel {
    
    // User has reviewed actions via the 'Edit Before Submit' modal and now has reviewed the graph via 'Approve And Submit' modal
    @MainActor
    func submitApprovedActionsToSupabase() {
        
        let state = self
        
        log("SubmitLLMActionsToSupabase called")
        log("📼 ⬆️ Uploading recording data to Supabase ⬆️ 📼")
        
        let actionsAsSteps = state.llmRecording.actions
        log("ShowLLMApprovalModal: actions: \(actionsAsSteps)")
        
        guard let deviceUUID = getDeviceUUID() else {
            fatalErrorIfDebug("SubmitLLMActionsToSupabase error: no device ID found.")
            return
        }
        
        guard let promptForTrainingDataOrCompletedRequest = state.llmRecording.promptForTrainingDataOrCompletedRequest else {
            fatalErrorIfDebug("SubmitLLMActionsToSupabase error: did not have prompt saved")
            return
        }
        
        // When submitting actions to Supabase, we *must* have a rating.
        // Submitting a correction = 5 star rating
        // Submitting a training example = whatever rating we gave in the earlier modal
        let isCorrection = state.llmRecording.mode == .augmentation
        let rating: StitchAIRating = isCorrection ? .fiveStars : (state.llmRecording.rating ?? .fiveStars)
        #if DEV_DEBUG
        if state.llmRecording.rating.isNotDefined && !isCorrection { fatalErrorIfDebug() }
        #endif
                
        Task { [weak state] in
            guard let state = state,
                  let supabaseManager = state.aiManager else {
                log("SubmitLLMActionsToSupabase error: no supabase")
                return
            }
            
            do {
                try await supabaseManager.uploadInferenceCallResultToSupabase(
                    prompt: promptForTrainingDataOrCompletedRequest,
                    finalActions: actionsAsSteps.map(\.toStep),
                    deviceUUID: deviceUUID,
                    // For fresh training example, we won't have this
                    requestId: state.llmRecording.requestIdFromCompletedRequest,
                    isCorrection: isCorrection,
                    rating: rating,
                    // these actions + prompt did not require a retry
                    requiredRetry: false)
                
                log("📼 ✅ Data successfully saved locally and uploaded to Supabase ✅ 📼")
                let existingPrompt = state.llmRecording.promptForTrainingDataOrCompletedRequest
                
                state.llmRecording = .init()
                
                // Save the prompt and rating just if we're exposing the training example helpers
                // TODO: can probably pass down this state etc. ?
                state.llmRecording.promptFromPreviousExistingGraphSubmittedAsTrainingData = existingPrompt
                state.llmRecording.ratingFromPreviousExistingGraphSubmittedAsTrainingData = rating
                
            } catch let encodingError as EncodingError {
                fatalErrorIfDebug("📼 ❌ Encoding error: \(encodingError.localizedDescription) ❌ 📼")
                state.llmRecording = .init()
            } catch let fileError as NSError {
                fatalErrorIfDebug("📼 ❌ File system error: \(fileError.localizedDescription) ❌ 📼")
                state.llmRecording = .init()
            } catch {
                fatalErrorIfDebug("📼 ❌ Error: \(error.localizedDescription) ❌ 📼")
                state.llmRecording = .init()
            }
        }
    }
}



struct StepActionDeletedFromEditModal: StitchDocumentEvent {
    let deletedStep: any StepActionable
    
    func handle(state: StitchDocumentViewModel) {
        log("StepActionDeletedFromEditModal: deletedStep: \(deletedStep)")
        log("StepActionDeletedFromEditModal: state.llmRecording.actions was: \(state.llmRecording.actions)")
        
        guard let deletedStep: any StepActionable = state.llmRecording.actions.first(where: { $0.toStep == deletedStep.toStep }) else {
            fatalErrorIfDebug()
            return
        }
                
        // Run deletion process for action
        deletedStep.removeAction(graph: state.visibleGraph,
                                   document: state)
        
        // Filter out removed action before re-applying actions
        let filteredActions = state.llmRecording.actions.filter { $0.toStep != deletedStep.toStep }
        
        state.llmRecording.actions = filteredActions
        
        // If we deleted the LLMAction that added a patch to the graph,
        // then we should also delete any LLMActions that e.g. changed that patch's nodeType or inputs.
        
        // We immediately "de-apply" the removed action(s) from graph,
        // so that user instantly sees what changed.
        if let error = state.reapplyActionsDuringEditMode(steps: state.llmRecording.actions) {
            // TODO: show this to the user?
            log("StepActionDeletedFromEditModal: error when reapplying actions: \(error)")
        }
    }
}
