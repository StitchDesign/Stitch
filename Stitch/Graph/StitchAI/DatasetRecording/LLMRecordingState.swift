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

// WE CANCELLED THE WHOLE THING
struct LLMAugmentationCancelled: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("LLMAugmentationCancelled called")
        state.llmRecording = .init()
    }
    
}

extension StitchDocumentViewModel {
    
    @MainActor
    func reapplyLLMActions() {
        log("StitchDocumentViewModel: reapplyLLMActions")
        // Wipe patches and layers
        // TODO: keep patches and layers that WERE NOT created by this recent LLM prompt? Folks may use AI to supplement their existing work.
        // Delete patches and layers that were created from actions;
        
        // NOTE: this llmRecording.actions will already reflect any edits the user has made to the list of actions
        let createdNodes = self.llmRecording.actions.reduce(into: IdSet()) { partialResult, step in
            if let id = step.nodeId,
               let uuid = UUID(uuidString: id) {
                partialResult.insert(uuid)
            }
        }
        
        createdNodes.forEach {
            self.graph.deleteNode(id: $0,
                                   willDeleteLayerGroupChildren: true)
        }
        
        // Apply the LLM-actions (model-generated and user-augmented) to the graph
        let actions = self.llmRecording.actions
        log("ShowLLMApprovalModal: actions: \(actions)")
        var canvasItemsAdded = 0
        actions.forEach { action in
            canvasItemsAdded = self.handleLLMStepAction(
                action,
                canvasItemsAdded: canvasItemsAdded)
        }
        
        // Write to disk
        self.encodeProjectInBackground()
        
        // Select the created nodes
        createdNodes.forEach { nodeId in
            if let node = self.graph.getNodeViewModel(nodeId) {
                // Will select a patch node or a layer nodes' inputs/outputs on canvas
                node.getAllCanvasObservers().forEach { (canvasItem: CanvasItemViewModel) in
                    canvasItem.select()
                }
            }
        }
    }
}

struct ShowLLMApprovalModal: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        log("ShowLLMApprovalModal called")
        
        state.reapplyLLMActions()
        
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
            (action.parseNodeId == deletedNode)
            
            // ConnectNodes
            || (action.fromNodeId?.parseNodeId == deletedNode)
            || (action.toNodeId?.parseNodeId == deletedNode)
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
            (action.parseNodeId == nodeId && action.parsePort() == thisLayerInput)
            
            // ConnectNodes to this specific layer input
            || (action.toNodeId?.parseNodeId == nodeId && action.parsePort() == thisLayerInput)
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
                    state.llmRecording.actions = state.llmRecording.actions.removeActionsForDeletedNode(deletedNode: nodeId)
                    // Also: remove any other actions that relied on this AddNode action
                    // e.g. cannot AddLayerInput if layer node longer exists
                    
                }
                
            case .addLayerInput:
                if let nodeId = deletedAction.parseNodeId,
                   let port = deletedAction.parsePort() {
                    
                    switch port {
                        
                    case .keyPath(let layerInputType):
                        // Also remove any incoming
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
                
//            case .connectNodes:
//                // Find the 'to' destination and wipe connection from there
//                if let nodeId = deletedAction.parseNodeId,
//                   let parsedPort = deletedAction.parsePort() {
//                    state.graph.removeEdgeAt(input: .init(portType: parsedPort,
//                                                          nodeId: nodeId))
//                }
//                
//                // ALTERNATIVELTY
//                
//            case .changeNodeType:
//                // just remove from the list... then rely on "wipe and recreate" to switch the (still-created?) node back to its default node type or some other node type (if there's another, non-deleted ChangeNodeType LLMAction)
//                
//            case .setInput:
//                // just remove from the list; 'wipe and recreate' will handle the rest properly
//            
                
            }
        }
        
        // ^^ can you handle this a little more intelligently?
        // would be nice to see the edits in live action; but a bit of a pain to decode them here now
        // and e.g. if you delete an AddNode action, then you need to delete the associated ChangeNodeType etc. actions
        
        // If immediately "de-apply" the removed action(s) from graph,
        // so that user instantly sees what changed.
        state.reapplyLLMActions()
        
    }
}

struct LLMApprovalModalView: View {
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Does this graph look correct?")
                .font(.headline)
            
            HStack {
                Button {
                    dispatch(ShowLLMEditModal())
                } label: {
                    Text("Add More")
                }
                
                Button {
                    // dispatch(ShowLLMEditModal())
                    // Actually submit to Supabase here
                    // call the logic in `SupabaseManager.uploadLLMRecording`
                    dispatch(SubmitLLMActionsToSupabase())
                } label: {
                    Text("Submit") // "Send to Supabase"
                }
            }
            
        }
//        .frame(maxWidth: 520)
        .padding()
        .background(.regularMaterial)
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
