//
//  LLMRecordingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftUI

let LLM_COLLECTION_DIRECTORY = "StitchDataCollection"

enum LLMRecordingMode: Equatable {
    case normal
    case augmentation
}

enum LLMRecordinModal: Equatable, Hashable {
    // No active modal
    case none
    
    // Modal from which we can edit the LLM actions (created by model + user)
    // and then either (1) test and submit or (2) completely cancel.
    case editBeforeSubmit
    
    // Modal from which either (1) re-enter LLM edit mode or (2) finally approve the LLM action list and send to Supabase
    case approveAndSubmit
}

struct LLMRecordingState: Equatable {
    
    // Are we actively recording redux-actions which we then turn into LLM-actions?
    var isRecording: Bool = false
    
    var mode: LLMRecordingMode = .normal
    
    var actions: [LLMStepAction] = .init()
    
    var promptState = LLMPromptState()
    
    var jsonEntryState = LLMJsonEntryState()
    
    var modal: LLMRecordinModal = .none
}

struct ShowLLMApprovalModal: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("ShowLLMApprovalModal called")
        
        // Wipe patches and layers
        state.graph.nodes.forEach { (key: UUID, value: NodeViewModel) in
            state.graph.deleteNode(
                id: key,
                willDeleteLayerGroupChildren: true)
        }
        
        // Apply the LLM-actions (model-generated and user-augmented) to the graph
        let actions = state.graph.lastAIGeneratedActions + state.llmRecording.actions
        log("ShowLLMApprovalModal: actions: \(actions)")
        var canvasItemsAdded = 0
        actions.forEach { action in
            canvasItemsAdded = state.handleLLMStepAction(
                action,
                canvasItemsAdded: canvasItemsAdded)
        }
        
        // Show modal
        state.llmRecording.modal = .approveAndSubmit
    }
}

struct ShowLLMEditModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("ShowLLMEditModal called")
        state.llmRecording.modal = .editBeforeSubmit
    }
}

struct SubmitLLMActionsToSupabase: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        
        Task {
            do {
                // UPLOAD TO SUPABASE
                log("📼 ⬆️ Uploading recording data to Supabase ⬆️ 📼")
              
                // TODO: JAN 25: these should be from the edited whatever...
                let actions = state.llmRecording.actions
                log("ShowLLMApprovalModal: actions: \(actions)")
                
                // previously: `showJSONEditor` was a callback that produced the new, edited actions;
                // but now, that data will just live in LLM Recording State
                // (and be edited by the JSONEditorView)
                try await SupabaseManager.shared.uploadEditedActions(
                    prompt: state.llmRecording.promptState.prompt,
                    finalActions: actions)
                                
                log("📼 ✅ Data successfully saved locally and uploaded to Supabase ✅ 📼")
                
            } catch let encodingError as EncodingError {
                log("📼 ❌ Encoding error: \(encodingError.localizedDescription) ❌ 📼")
            } catch let fileError as NSError {
                log("📼 ❌ File system error: \(fileError.localizedDescription) ❌ 📼")
            } catch {
                log("📼 ❌ Error: \(error.localizedDescription) ❌ 📼")
            }
            
        } // Task
        
    } // handle
}

struct LLMActionsUpdated: StitchDocumentEvent {
    let newActions: [Step]
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMActionsUpdated: newActions: \(newActions)")
        log("LLMActionsUpdated: state.llmRecording.actions was: \(state.llmRecording.actions)")
        state.llmRecording.actions = newActions
    }
}

struct LLMApprovalModalView: View {
    
    var body: some View {
        HStack {
            Button {
                dispatch(ShowLLMEditModal())
            } label: {
                Text("Edit")
            }
            
            Button {
                // dispatch(ShowLLMEditModal())
                // Actually submit to Supabase here
                // call the logic in `SupabaseManager.uploadLLMRecording`
                
                
                
            } label: {
                Text("Submit") // "Send to Supabase"
            }
            
            VStack(alignment: .leading) {
                Text("Does this ")
                    .font(.headline)
                Text("Prototypes are paused to enable inspection of faults in your graph. This is useful for debugging hangs in your prototype. Root causes could include a high loop count in some node's input field.")
                    .font(.subheadline)
            }
            .frame(maxWidth: 520)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
}

// Might not need this anymore ?
// Also overlaps with `StitchAIPromptState` ?
struct LLMPromptState: Equatable {
    // can even show a long scrollable json of the encoded actions, so user can double check
    var showModal: Bool = false
    
    var prompt: String = ""
        
    // cached; updated when we open the prompt modal
    // TODO: find a better way to write the view such that the json's (of the encoded actions) keys are not shifting around as user types
    var actionsAsDisplayString: String = ""
}

struct LLMJsonEntryState: Equatable {
    var showModal = false
    
    var jsonEntry: String = ""
    
    // Mapping of LLM node ids (e.g. "123456") to the id created
    var llmNodeIdMapping = LLMNodeIdMapping()
}

typealias LLMNodeIdMapping = [String: NodeId]

extension StitchDocumentViewModel {
    @MainActor
    var llmNodeIdMapping: LLMNodeIdMapping {
        get {
            self.llmRecording.jsonEntryState.llmNodeIdMapping
        } set(newValue) {
            self.llmRecording.jsonEntryState.llmNodeIdMapping = newValue
        }
    }
}
