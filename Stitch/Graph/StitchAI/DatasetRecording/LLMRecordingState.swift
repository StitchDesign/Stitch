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
    
    // Are we actively recording redux-actions which we then turn into LLM-actions?
    var isRecording: Bool = false
    
    // Do not create LLMActions while we are applying LLMActions
    var isApplyingActions: Bool = false
    
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
                
                log("LLMRecordingState: nodeIdToNameMapping: \(acc)")
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

extension StitchDocumentViewModel {

    func nodesCreatedByLLMActions(_ actions: [StepTypeAction]) -> IdSet {
        
        let createdNodes = actions.reduce(into: IdSet()) { partialResult, step in
            if case let .addNode(x) = step {
                partialResult.insert(x.nodeId)
            }
        }
        
        log("StitchDocumentViewModel: wipeNodesCreatedFromLLMActions: createdNodes: \(createdNodes)")
        
        return createdNodes
    }
    
    @MainActor
    func validateAndApplyActions(_ actions: [StepTypeAction]) {
        
        var canvasItemsAdded = 0
        
        // Are these steps valid?
        // invalid = e.g. tried to create a connection for a node before we created that node
        if !actions.areLLMStepsValid() {
            // immediately enter correction-mode: one of the actions, or perhaps the ordering, was incorrect
            // TODO: JAN 31: enter correction-mode for these parsed-step
            log("validateAndApplyActions: will show edit modal: invalid actions: \(actions)")
            self.startLLMAugmentationMode()
            return
        }
        
        for action in actions {
            if let _canvasItemsAdded = self.applyAction(
                action,
                canvasItemsAdded: canvasItemsAdded) {
                
                canvasItemsAdded = _canvasItemsAdded
            } else {
                // immediately enter correction-mode: we were not able to apply one of the actions
                log("validateAndApplyActions: will show edit modal: could not appply action: \(action)")
                // TODO: should we also remove the action that could not be parsed?
                self.startLLMAugmentationMode()
                return
            }
        }
        
        // Only adjust node positions if we were successful
        self.positionAIGeneratedNodes()
        
        // Write to disk ONLY IF WE WERE SUCCESSFUL
        self.encodeProjectInBackground()
    }
    
    @MainActor
    func positionAIGeneratedNodes() {
        
        let adjacency = AdjacencyCalculator()
        
        // Assumes actions already validated and applicable
        self.llmRecording.actions.forEach { action in
            if case let .connectNodes(x) = action {
                adjacency.addEdge(from: x.fromNodeId, to: x.toNodeId)
            }
        }
        
        // no depth map if no connections?
        let (depthMap, hasCycle) = adjacency.computeDepth()
        
        guard let depthMap = depthMap,
              !hasCycle else {
            // TODO: JAN 31: if the model created a cycle... should we retry? or is that okay?
            fatalErrorIfDebug("Had cycle or could not create depth-map")
            return
        }
        
        
        
        let depthLevels = depthMap.values.sorted().toOrderedSet

        let createdNodes = nodesCreatedByLLMActions(self.llmRecording.actions)
        
        // Iterate by depth-level, so that nodes at same depth (e.g. 0) can be y-offset from each other
        depthLevels.enumerated().forEach {
            let depthLevel: Int = $0.element
            let depthLevelIndex: Int = $0.offset

            // TODO: just rewrite the adjacency logic to be a mapping of [Int: [UUID]] instead of [UUID: Int]
            // Find all the created-nodes at this depth-level,
            // and adjust their positions
            let createdNodesAtThisLevel = createdNodes.compactMap {
                if depthMap.get($0) == depthLevel {
                    return self.graph.getNodeViewModel($0)
                }
                return nil
            }
            
            createdNodesAtThisLevel.forEach { createdNode in
                createdNode.getAllCanvasObservers().enumerated().forEach { canvasItemAndIndex in
                    let newPosition =  CGPoint(
                        x: self.viewPortCenter.x + (CGFloat(depthLevel) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER),
                        y: self.viewPortCenter.y + (CGFloat(canvasItemAndIndex.offset) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER/2) + (CGFloat(depthLevelIndex) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER/2)
                    )
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
        let createdNodes = nodesCreatedByLLMActions(self.llmRecording.actions)
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
