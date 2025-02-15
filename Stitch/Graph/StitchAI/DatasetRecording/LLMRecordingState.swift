//
//  LLMRecordingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine


let LLM_COLLECTION_DIRECTORY = "StitchDataCollection"

enum LLMRecordingMode: Equatable {
    case normal
    case augmentation
}

enum LLMRecordinModal: Equatable, Hashable {
    // No active modal
    case none
    
    // Modal from which user can edit LLM Actions (remove those created by model or user; add new ones by interacting with the graph)
    case editBeforeSubmit
    
    // Modal from which either (1) re-enter LLM edit mode or (2) finally approve the LLM action list and send to Supabase
    case approveAndSubmit
}

struct LLMRecordingState: Equatable {
    
    var recentOpenAIRequestCompleted: Bool = false {
        didSet {
            // When a request is completed and we're recording, switch to augmentation mode
            if recentOpenAIRequestCompleted && isRecording {
                mode = .augmentation
            }
        }
    }
    
    // Are we actively recording redux-actions which we then turn into LLM-actions?
    var isRecording: Bool = false
    
    // Track whether we've shown the modal in normal mode
    var hasShownModalInNormalMode: Bool = false
    
    // Do not create LLMActions while we are applying LLMActions
    var isApplyingActions: Bool = false
    
    // Error from validating or applying the LLM actions;
    // Note: we can actually have several, but only display one at a time
    var actionsError: LLMActionsInvalidMessage?
    
    var attempts: Int = 0
    
    static let maxAttempts: Int = 3
    
    var mode: LLMRecordingMode = .normal
    
    var actions: [StepTypeAction] = .init() {
        didSet {
            var acc = [NodeId: PatchOrLayer]()
            self.actions.forEach { action in
                // Add Node step uses nodeId; but Connect Nodes step uses toNodeId and fromNodeId
                if case let .addNode(x) = action {
                    acc.updateValue(x.nodeName, forKey: x.nodeId)
                }
            } // forEach
            return self.nodeIdToNameMapping = acc
        }
    }
    
    var promptState = LLMPromptState()
    
    var jsonEntryState = LLMJsonEntryState()
    
    var modal: LLMRecordinModal = .none

    // Maps nodeIds to Patch/Layer name;
    // Also serves as source of truth for which nodes (ids) have been created by

    // Alternatively: use a stored var that is updated by `self.actions`'s `didSet`
    // Note: it's okay for this just to be patch nodes and entire layer nodes; any layer inputs from an AI-created layer node will be 'blue'
    var nodeIdToNameMapping: [NodeId: PatchOrLayer] = .init()
    
}

extension [StepTypeAction] {
    func nodesCreatedByLLMActions() -> IdSet {
        let createdNodes = self.reduce(into: IdSet()) { partialResult, step in
            if case let .addNode(x) = step {
                partialResult.insert(x.nodeId)
            }
        }
        log("nodesCreatedByLLMActions: createdNodes: \(createdNodes)")
        return createdNodes
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func validateAndApplyActions(_ actions: [StepTypeAction]) {
        
        // Wipe old error reason
        self.llmRecording.actionsError = nil
        
        // Are these steps valid?
        // invalid = e.g. tried to create a connection for a node before we created that node
    
        if let invalidReason = actions.areLLMStepsValid() {
            log("validateAndApplyActions: will show edit modal: invalid actions: \(actions)")
            // immediately enter correction-mode: one of the actions, or perhaps the ordering, was incorrect
            self.llmRecording.actionsError = invalidReason
            self.startLLMAugmentationMode()
            return
        }
        
        for action in actions {
            // We may also encounter
            if let invalidReason = self.applyAction(action) {
                self.llmRecording.actionsError = invalidReason
                self.startLLMAugmentationMode()
                return
            }
        }
        
        // Only adjust node positions if actions were valid and successfully applied
        self.positionAIGeneratedNodes()
        
        // Write to disk ONLY IF WE WERE SUCCESSFUL
        self.encodeProjectInBackground()
    }
    
    
    @MainActor
    func positionAIGeneratedNodes() {
        
        let (depthMap, hasCycle) = calculateAINodesAdjacency(self.llmRecording.actions)
        
        guard let depthMap = depthMap,
              !hasCycle else {
            // TODO: JAN 31: if the model created a cycle... should we retry? or is that okay?
            fatalErrorIfDebug("Had cycle or could not create depth-map")
            return
        }
                        
        let depthLevels = depthMap.values.sorted().toOrderedSet

        let createdNodes = self.llmRecording.actions.nodesCreatedByLLMActions()
        
        // Iterate by depth-level, so that nodes at same depth (e.g. 0) can be y-offset from each other
//        depthLevels.enumerated().forEach {
        depthLevels.forEach {
            let depthLevel: Int = $0// .element
//            let depthLevelIndex: Int = $0.offset

            // TODO: just rewrite the adjacency logic to be a mapping of [Int: [UUID]] instead of [UUID: Int]
            // Find all the created-nodes at this depth-level,
            // and adjust their positions
            let createdNodesAtThisLevel = createdNodes.compactMap {
                if depthMap.get($0) == depthLevel {
                    return self.graph.getNodeViewModel($0)
                }
                log("Could not get depth level for \($0.debugFriendlyId)")
                return nil
            }
            
            createdNodesAtThisLevel.enumerated().forEach { x in
                let createdNode = x.element
                let createdNodeIndexAtThisDepthLevel = x.offset
                log("createdNode.id: \(createdNode.id)")
                log("createdNodeIndexAtThisDepthLevel: \(createdNodeIndexAtThisDepthLevel)")
                createdNode.getAllCanvasObservers().enumerated().forEach { canvasItemAndIndex in
                    let newPosition =  CGPoint(
                        x: self.viewPortCenter.x + (CGFloat(depthLevel) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER),
                        y: self.viewPortCenter.y + (CGFloat(canvasItemAndIndex.offset) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER) + (CGFloat(createdNodeIndexAtThisDepthLevel) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER)
                    )
                    log("canvasItemAndIndex.element.id: \(canvasItemAndIndex.element.id)")
                    log("newPosition: \(newPosition)")
                    canvasItemAndIndex.element.position = newPosition
                    canvasItemAndIndex.element.previousPosition = newPosition
                }
            }
        }
    
    }
    
    @MainActor
    func reapplyActions() {
        let actions = self.llmRecording.actions
        
        log("StitchDocumentViewModel: reapplyLLMActions: actions: \(actions)")
        // Wipe patches and layers
        // TODO: keep patches and layers that WERE NOT created by this recent LLM prompt? Folks may use AI to supplement their existing work.
        // Delete patches and layers that were created from actions;
        
        // NOTE: this llmRecording.actions will already reflect any edits the user has made to the list of actions
        let createdNodes = self.llmRecording.actions.nodesCreatedByLLMActions()
        createdNodes.forEach {
            self.graph.deleteNode(id: $0,
                                   willDeleteLayerGroupChildren: true)
        }
        
        // Apply the LLM-actions (model-generated and user-augmented) to the graph
        self.validateAndApplyActions(actions)
        
        // TODO: also select the nodes when we first successfully parse?
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

// TODO: remove?
struct LLMJsonEntryState: Equatable {
    var showModal = false
    
    var jsonEntry: String = ""
    
    // Mapping of LLM node ids (e.g. "123456") to the id created
    // TODO: no longer needed, since LLM now provides real UUIDs which we use with the node?
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
