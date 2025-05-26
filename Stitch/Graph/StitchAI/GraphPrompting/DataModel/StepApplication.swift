//
//  StepApplication.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation


// MARK: RECEIVING A LIST OF LLM-STEP-ACTIONS (i.e. `Step`) AND TURNING EACH ACTION INTO A STATE CHANGE

//let CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER = 400.0
let CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER: CGFloat = 600.0 // needed for especially wide nodes

//let CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER = 100.0
let CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER: CGFloat = 300.0 // needed for when nodes are at same topo depth level

extension Array where Element == any StepActionable {
    func nodesCreatedByLLMActions() -> IdSet {
        let createdNodes = self.reduce(into: IdSet()) { partialResult, step in
            if let addNodeAction = step as? StepActionAddNode {
                partialResult.insert(addNodeAction.nodeId)
            } else if let layerGroupCreated = step as? StepActionLayerGroupCreated {
                partialResult.insert(layerGroupCreated.nodeId)
            }
        }
        log("nodesCreatedByLLMActions: createdNodes: \(createdNodes)")
        return createdNodes
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func validateAndApplyActions(_ convertedActions: [any StepActionable]) -> StitchAIStepHandlingError? {
        
        // Wipe old error reason
        self.llmRecording.actionsError = nil
        
        // Are these steps valid?
        // invalid = e.g. tried to create a connection for a node before we created that node
        if let validationError = convertedActions.validateLLMSteps() {
            self.llmRecording.actionsError = validationError.description
            // Immediately enter correction-mode: one of the actions, or perhaps the ordering, was incorrect
            self.startLLMAugmentationMode()
            log("validateAndApplyActions: hit error when validating LLM-actions: \(convertedActions) ... error was: \(validationError)")
            return validationError
        }
        
        for action in convertedActions {
            if let addAction = (action as? StepActionAddNode) {
                // add-node actions cannot re-use IDs
                assertInDebug(!self.visibleGraph.nodes.keys.contains(addAction.nodeId))
            }
            
            if let layerGroupCreatedAction = (action as? StepActionLayerGroupCreated) {
                // layer-group-created actions cannot re-use IDs
                assertInDebug(!self.visibleGraph.nodes.keys.contains(layerGroupCreatedAction.nodeId))
            }
            
            if let error = self.applyAction(action) {
                self.llmRecording.actionsError = error.description
                self.startLLMAugmentationMode()
                log("validateAndApplyActions: encountered error while trying to apply LLM-actions: \(error)")
                return error
            }
        }
        
        // Only adjust node positions if actions were valid and successfully applied
        positionAIGeneratedNodes(convertedActions: convertedActions,
                                 nodes: self.visibleGraph.visibleNodesViewModel,
                                 viewPortCenter: self.newCanvasItemInsertionLocation,
                                 graph: graph)
        
        self.graphUpdaterId = .randomId() // NOT NEEDED, ACTUALLY?
        
        return nil // no error
    }
    
    
    // We've decoded the OpenAI json-response into an array of `LLMStepAction`;
    // Now we turn each `LLMStepAction` into a state-change.
    // TODO: better?: do more decoding logic on the `LLMStepAction`-side; e.g. `LLMStepAction.nodeName` should be type `PatchOrLayer` rather than `String?`
    
        
    // fka `handleLLMStepAction`
    // returns nil = failed, and should retry
    @MainActor
    func applyAction<ActionType: StepActionable>(_ action: ActionType) -> StitchAIStepHandlingError? {
        
        // Set true whenever we are
        self.llmRecording.isApplyingActions = true
                        
        if let error = action.applyAction(document: self) {
            return error
        }
        
        // TODO: why was this needed in AI Generation mode? (added to resolve an AI-generation-mode-only issue where press interaction's outputs would be empty when creating an edge to an option switch node)
        self.visibleGraph.updateGraphData(self)
        
        self.llmRecording.isApplyingActions = false
        
        return nil
    }
    
    // Remove actions' effects from the current document
    @MainActor
    func deapplyActions(actions: [any StepActionable]) {
        // While de-applying actions, we should not be deriving new actions;
        // `isApplyingActions = true` blocks the derivation of new actions from graph changes / persistence
        self.llmRecording.isApplyingActions = true
        
        actions.reversed().forEach {
            $0.removeAction(graph: graph, document: self)
        }
        
        self.llmRecording.isApplyingActions = false
    }
    
    @MainActor
    func onNewStepReceived(originalSteps: [any StepActionable],
                           newStep: any StepActionable) -> StitchAIStepHandlingError? {
        
        // 'De-apply' (i.e. remove the effects of) the original actions
        self.deapplyActions(actions: originalSteps)
        
        // Then apply the original actions + the new action
        let newSteps = originalSteps + [newStep]

        self.llmRecording.actions = newSteps
        
        if let validationError = self.validateAndApplyActions(newSteps) {
            return validationError
        }
        
        return nil // no error
    }
    
    
    /*
     This function has two use cases:
     
     1. We are in edit mode and delete an action (`LLMActionDeletedFromEditModal`).
     We have already deleted the action and now re-apply the remaining actions, to adjust their positions. (And what else?)
     
     2. We are streaming a response and have received a new step, which needs to be validated (e.g. validation fails if we received a SetInput that refers to a node that does not yet exist); we may also need to adjust nodes' positions

     */
    
    // TODO: pass down the [Step] explicitly ?
    @MainActor
    func reapplyActionsDuringEditMode(steps: [any StepActionable]) -> StitchAIStepHandlingError? {
        let graph = self.visibleGraph
        
        log("StitchDocumentViewModel: reapplyLLMActions: steps: \(steps)")
        
        // Do not save or apply nodes' positions when streaming
        self.llmRecording.canvasItemPositions = steps.reduce(into: [CanvasItemId : CGPoint]()) { result, action in
            if let nodeId = (action as? StepActionAddNode)?.nodeId ?? (action as? StepActionLayerGroupCreated)?.nodeId {
                graph.getNode(nodeId)?.getAllCanvasObservers().forEach {
                    result.updateValue($0.position,forKey: $0.id)
                }
            }
        }

        // Remove all actions before re-applying
        self.deapplyActions(actions: steps)
        
        // Apply the LLM-actions (model-generated and user-augmented) to the graph
        if let error = self.validateAndApplyActions(steps) {
            return error
        }
        
        // Update node positions to reflect previous position
        self.llmRecording.canvasItemPositions.forEach { canvasId, canvasPosition in
            if let canvas = graph.getCanvasItem(canvasId) {
                canvas.position = canvasPosition
                canvas.previousPosition = canvasPosition
            }
        }
        
        // Force update of view
        self.graphUpdaterId = .randomId() // TODO: not needed?
        
        // After we have de-applied and then re-applied the actions,
        // derive a new actions based on post-"de-apply, re-apply" state
        // and confirm that de-applying and re-applying the actions
        // did not cause the actions to change
        
        // Validates that action data didn't change after derived actions is computed
        let newActions = Self.deriveNewAIActions(
            oldGraphEntity: self.llmRecording.initialGraphState,
            visibleGraph: self.visibleGraph)
        
        return Self.validateActionsDidNotChangeDuringReapply(
            oldActions: steps,
            newActions: newActions)
    }
        
    private static func validateActionsDidNotChangeDuringReapply(oldActions: [any StepActionable],
                                                                 newActions: [any StepActionable]) -> StitchAIStepHandlingError? {
        
        // TODO: why or how is the count changing? What is mutating the `newActions` count?
        assertInDebug(oldActions.count == newActions.count)
        log("oldActions.count: \(oldActions.count)")
        log("newActions.count: \(newActions.count)")
        
        for (oldAction, newAction) in zip(oldActions, newActions) {
            if oldAction.toStep != newAction.toStep {
                log("Found unequal actions: oldAction: \(oldAction)")
                log("Found unequal actions: newAction: \(newAction)")
                fatalErrorIfDebug() // Crash on dev
                return .actionValidationError("Found unequal actions:\n\(oldAction)\n\(newAction)")
            }
        }
        
        return nil
    }
}

@MainActor
func positionAIGeneratedNodes(convertedActions: [any StepActionable],
                              nodes: VisibleNodesViewModel,
                              viewPortCenter: CGPoint,
                              graph: GraphReader) {
    
    // TODO: if we have a chain of nodes, shift our starting point further west
    //    var viewPortCenter = viewPortCenter
    //    viewPortCenter.x -= 500 // We actually shift left a little bit, so nodes look like they're crawling from left to right
    
    let (depthMap, hasCycle) = convertedActions.calculateAINodesAdjacency()
    
    guard let depthMap = depthMap,
          !hasCycle else {
        fatalErrorIfDebug("Did not have a cycle but was not able create depth-map")
        return
    }
    
    guard !depthMap.isEmpty else {
//        fatalErrorIfDebug("Depth-map should never be empty")
        log("Depth-map should never be empty") // can be empty if we have no nodes
        return
    }
                    
    let depthLevels = depthMap.values.sorted().toOrderedSet

    let createdNodes = convertedActions.nodesCreatedByLLMActions()
        
    // Iterate by depth-level, so that nodes at same depth (e.g. 0) can be y-offset from each other
    depthLevels.forEach { depthLevel in

        // TODO: just rewrite the adjacency logic to be a mapping of [Int: [UUID]] instead of [UUID: Int]
        // Find all the created-nodes at this depth-level,
        // and adjust their positions
        let createdNodesAtThisLevel = createdNodes.compactMap {
            if depthMap.get($0) == depthLevel {
                return nodes.getNode($0)
            }
            log("positionAIGeneratedNodes: Could not get depth level for \($0.debugFriendlyId)")
            return nil
        }
        
        createdNodesAtThisLevel.enumerated().forEach { x in
            let createdNode = x.element
            let createdNodeIndexAtThisDepthLevel = x.offset
            // log("positionAIGeneratedNodes: createdNode.id: \(createdNode.id)")
            // log("positionAIGeneratedNodes: createdNodeIndexAtThisDepthLevel: \(createdNodeIndexAtThisDepthLevel)")
            
            createdNode.getAllCanvasObservers().enumerated().forEach { x in
                
                let canvasItem = x.element
                let canvasItemIndex = x.offset
                
                var size: CGSize = canvasItem.getHardcodedSize(graph)
                ?? CGSize(width: CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER,
                          height: CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER)
                
//                log("positionAIGeneratedNodes: size for \(canvasItem.id): \(String(describing: size))")
                
                // Add some 'padding' to the canvas item's size, so items do not end up right next to each other
                let padding: CGFloat = 36.0
                size.width += padding
                size.height += padding
                               
                let newPosition =  CGPoint(
                    x: viewPortCenter.x + (CGFloat(depthLevel) * size.width),
                    y: viewPortCenter.y + (CGFloat(canvasItemIndex) * size.height) + (CGFloat(createdNodeIndexAtThisDepthLevel) * size.height)
                )
                                
//                 log("positionAIGeneratedNodes: canvasItemAndIndex.element.id: \(canvasItemAndIndex.element.id)")
//                 log("positionAIGeneratedNodes: newPosition: \(newPosition)")
                canvasItem.position = newPosition
                canvasItem.previousPosition = newPosition
            }
        }
    }
}


