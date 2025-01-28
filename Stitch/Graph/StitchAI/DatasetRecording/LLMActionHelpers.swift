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
        
        // Don't need to do this again here, since we've already done it whenever user edits the LLMAction list
        // TODO: should not need to do this final application again, not really?
        state.reapplyLLMActions()
        
        // End recording when we open the final submit
        state.llmRecordingEnded()
        
        // Show modal
        state.llmRecording.modal = .approveAndSubmit
    }
}

struct ShowLLMEditModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("ShowLLMEditModal called")

        state.llmRecording.isRecording = true
        
        // Always treat edit modal as an augmentation
        state.llmRecording.mode = .augmentation
        
        state.llmRecording.modal = .editBeforeSubmit
    }
}

struct SubmitLLMActionsToSupabase: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("SubmitLLMActionsToSupabase called")
        
        Task {
            do {
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
                state.llmRecording = .init()
                
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
            
        } // Task
        
    } // handle
}

extension LLMStepActions {
    func removeActionsForDeletedNode(deletedNode: NodeId) -> Self {
        var actions = self
        
        actions.removeAll(where: { action in
            
            // SetInput, ChangeNodeType, AddLayerInput
            if (action.parseNodeId == deletedNode)
            
            // ConnectNodes
            || (action.fromNodeId?.parseNodeId == deletedNode)
                || (action.toNodeId?.parseNodeId == deletedNode) {
                log("removeActionsForDeletedNode: will remove action \(action)")
                return true
            } else {
                return false
            }
        })
        
        return actions
    }
    
    func removeActionsForDeletedLayerInput(nodeId: NodeId,
                                           // Assumes packed; LLModel only works with packed layer inputs
                                           deletedLayerInput: LayerInputType) -> Self {
        var actions = self

        let thisLayerInput = NodeIOPortType.keyPath(deletedLayerInput)
        
        actions.removeAll(where: { action in
            // SetInput for this specific layer input
            if (action.parseNodeId == nodeId && action.parsePort() == thisLayerInput)
            
            // ConnectNodes to this specific layer input
                || (action.toNodeId?.parseNodeId == nodeId && action.parsePort() == thisLayerInput) {
                log("removeActionsForDeletedLayerInput: will remove action \(action)")
                return true
            } else {
                return false
            }
        })
        
        return actions
    }
}

struct LLMActionDeleted: StitchDocumentEvent {
    let deletedAction: Step
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMActionsUpdated: deletedAction: \(deletedAction)")
        log("LLMActionsUpdated: state.llmRecording.actions was: \(state.llmRecording.actions)")
        
        // Note: fine to do equality check because not editing actions per se here
        // TODO: what if we change the `value` of
        let filteredActions = state.llmRecording.actions.filter { $0 != deletedAction }
        
        state.llmRecording.actions = filteredActions
                
        // If we deleted the LLMAction that added a patch to the graph,
        // then we should also delete any LLMActions that e.g. changed that patch's nodeType or inputs.
        if let stepType = StepType(rawValue: deletedAction.stepType) {
            
            switch stepType {
                
            case .addNode:
                if let nodeId = deletedAction.parseNodeId {
                    state.graph.deleteNode(id: nodeId, willDeleteLayerGroupChildren: true)
                    
                    // Remove any other actions that relied on this AddNode action
                    // e.g. cannot AddLayerInput if layer node longer exists
                    state.llmRecording.actions = state.llmRecording.actions.removeActionsForDeletedNode(deletedNode: nodeId)
                }
                
            case .addLayerInput:
                if let nodeId = deletedAction.parseNodeId,
                   let port = deletedAction.parsePort() {
                    
                    switch port {
                        
                    case .keyPath(let layerInputType):
                        state.llmRecording.actions = state.llmRecording.actions.removeActionsForDeletedLayerInput(
                            nodeId: nodeId,
                            deletedLayerInput: layerInputType)
                        
                    case .portIndex(let x):
                        log("Unexpected port type when removing AddLayerInput action \(x)")
                        fatalErrorIfDebug()
                    }
                }
                
                
            case .connectNodes, .changeNodeType, .setInput:
                // deleting these LLMActions does not require us to delete any other LLMActions;
                // we just 'wipe and replay LLMActions'
                log("do not need to delete any other other LLMActions")
            }
        }
                
        // If immediately "de-apply" the removed action(s) from graph,
        // so that user instantly sees what changed.
        state.reapplyLLMActions()
    }
}
