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
        
        // For augmentation mode, continue with approval flow
        do {
            try state.reapplyActions()
        } catch let error as StitchFileError {
            state.showErrorModal(message: error.description,
                                 userPrompt: "")
        } catch {
            log("ShowLLMApprovalModal error: \(error.localizedDescription)")
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

        state.llmRecording.isRecording = true
        
        // Always treat edit modal as an augmentation
//        state.llmRecording.mode = .augmentation
        
        state.llmRecording.modal = .editBeforeSubmit
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
            let actions: [StepTypeAction] = state.llmRecording.actions
            log("ShowLLMApprovalModal: actions: \(actions)")
            
            let actionsAsSteps: [Step] = actions.map { $0.toStep() }
            
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

extension [StepTypeAction] {
    func removeActionsForDeletedNode(deletedNode: NodeId) -> Self {
        var actions = self
        actions.removeAll(where: { action in
            switch action {
            case .addNode(let x):
                return x.nodeId == deletedNode
            case .setInput(let x):
                return x.nodeId == deletedNode
            case .connectNodes(let x):
                return x.fromNodeId == deletedNode || x.toNodeId == deletedNode
            case .changeValueType(let x):
                return x.nodeId == deletedNode
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
            switch action {
            case .setInput(let x):
                // We had set the input for this specific layer node, at this specific port
                return x.nodeId == nodeId && x.port == thisLayerInput
            case .connectNodes(let x):
                // We had created an edge for to this specific layer's node specific port
                return x.toNodeId == nodeId && x.port == thisLayerInput
            default: // NodeType, CreateNode etc. not affected just by removing a layer node's input from the graph
                return false
            }
        })
        return actions
    }
}

struct LLMActionsUpdatedByModal: StitchDocumentEvent {
    let newActions: [StepTypeAction]
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMActionsUpdated: newActions: \(newActions)")
        log("LLMActionsUpdated: state.llmRecording.actions was: \(state.llmRecording.actions)")
        state.llmRecording.actions = newActions
        try? state.reapplyActions()
    }
}

struct LLMActionDeleted: StitchDocumentEvent {
    let deletedAction: StepTypeAction
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMActionsUpdated: deletedAction: \(deletedAction)")
        log("LLMActionsUpdated: state.llmRecording.actions was: \(state.llmRecording.actions)")
        
        // Note: fine to do equality check because not editing actions per se here
        // TODO: what if we change the `value` of
        let filteredActions = state.llmRecording.actions.filter { $0 != deletedAction }
        
        state.llmRecording.actions = filteredActions
                
        // If we deleted the LLMAction that added a patch to the graph,
        // then we should also delete any LLMActions that e.g. changed that patch's nodeType or inputs.
            
        switch deletedAction {
            
        case .addNode(let x):
            state.graph.deleteNode(id: x.nodeId,
                                   willDeleteLayerGroupChildren: true)
            
            // Remove any other actions that relied on this AddNode action
            state.llmRecording.actions = state.llmRecording.actions
                .removeActionsForDeletedNode(deletedNode: x.nodeId)

        case .connectNodes, .changeValueType, .setInput:
            // deleting these LLMActions does not require us to delete any other LLMActions;
            // we just 'wipe and replay LLMActions'
            log("do not need to delete any other other LLMActions")
        }
                
        // If immediately "de-apply" the removed action(s) from graph,
        // so that user instantly sees what changed.
        try? state.reapplyActions()
    }
}
