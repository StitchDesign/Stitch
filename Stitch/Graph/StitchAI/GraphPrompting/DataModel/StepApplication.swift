//
//  StepApplication.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation

extension Array where Element == any StepActionable {
    /// Ensures newly created nodes won't overwrite the graph.
    func remapNodeIdsForNewNodes() -> Self {
        // Old : New pairings
        var idMap = [NodeId : NodeId]()
        
        self.forEach {
            if let addNodeAction = $0 as? StepActionAddNode {
                idMap.updateValue(.init(), forKey: addNodeAction.nodeId)
            }
            
            if let addNodeAction = $0 as? StepActionLayerGroupCreated {
                idMap.updateValue(.init(), forKey: addNodeAction.nodeId)
            }
        }
        
        let convertedIdSteps = self.map { step in
            step.remapNodeIds(nodeIdMap: idMap)
        }
        
        return convertedIdSteps
    }
    
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
    func validateAndApplyActions(_ convertedActions: [any StepActionable],
                                 isNewRequest: Bool) -> StitchAIStepHandlingError? {
        // Wipe old error reason
        self.llmRecording.actionsError = nil
        
        var convertedActions = convertedActions
          
        // TODO: handle the fact that OpenAI may send us the same node ids over and over again; i.e. ids will be unique across all the actions sent for a given request, but ids may be same across multiple different requests; e.g. first request for "Add 1 and 2 and then Divide by 3" will use NodeIds X and Y, but then a second request for "Multiply 3 and 3 and Subtract by 9" will use the same NodeIds X and Y
//        if isNewRequest {
//            // Change Ids for newly created nodes
//            convertedActions = convertedActions.remapNodeIdsForNewNodes()
//        }
        
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
    
    
    
    /*
     This function has two use cases:
     
     1. We are in edit mode and delete an action (`LLMActionDeletedFromEditModal`).
     We have already deleted the action and now re-apply the remaining actions, to adjust their positions. (And what else?)
     
     2. We are streaming a response and have received a new step, which needs to be validated (e.g. validation fails if we received a SetInput that refers to a node that does not yet exist); we may also need to adjust nodes' positions

     */
    
    // TODO: pass down the [Step] explicitly ?
    @MainActor
    func reapplyActions(// steps: [Step],
                        isStreaming: Bool,
                        isNewRequest: Bool) -> StitchAIStepHandlingError? {
        let oldActions: [Step] = self.llmRecording.actions
        
        let conversionAttempt = oldActions.convertSteps()
        guard let actions: [any StepActionable] = conversionAttempt.value else {
            return conversionAttempt.error
        }
        
        let graph = self.visibleGraph
        
        log("StitchDocumentViewModel: reapplyLLMActions: actions: \(actions)")
        
        // Do not save or apply nodes' positions when streaming
        if !isStreaming {
            self.llmRecording.canvasItemPositions = actions.reduce(into: [CanvasItemId : CGPoint]()) { result, action in
                if let nodeId = (action as? StepActionAddNode)?.nodeId ?? (action as? StepActionLayerGroupCreated)?.nodeId {
                    graph.getNode(nodeId)?.getAllCanvasObservers().forEach {
                        result.updateValue($0.position,forKey: $0.id)
                    }
                }
            }
        }

        // Remove all actions before re-applying
        self.deapplyActions(actions: actions)
        
        // Apply the LLM-actions (model-generated and user-augmented) to the graph
        if let error = self.validateAndApplyActions(actions, isNewRequest: isNewRequest) {
            return error
        }
        
        // Update node positions to reflect previous position
        if !isStreaming {
            self.llmRecording.canvasItemPositions.forEach { canvasId, canvasPosition in
                if let canvas = graph.getCanvasItem(canvasId) {
                    canvas.position = canvasPosition
                    canvas.previousPosition = canvasPosition
                }
            }
        }
        
        // TODO: should we really do this? why do we need to do this?
        // After we have de-applied and then re-applied the actions,
        // derive a new actions based on post-"de-apply, re-apply" state
        // and confirm that de-applying and re-applying the actions
        // did not cause the actions to change
    
        
        // TODO: should we really do this? If we're re-applying actions, we just want to see
                            
        self.llmRecording.actions = Self.deriveNewAIActions(
            oldGraphEntity: self.llmRecording.initialGraphState,
            visibleGraph: self.visibleGraph)
        
        // Force update of view
        self.graphUpdaterId = .randomId() // TODO: not needed?
        
        if isStreaming {
            return nil
        } else {
            // Validates that action data didn't change after derived actions is computed
            return Self.validateActionsDidNotChangeDuringReapply(
                oldActions: oldActions,
                newActions: self.llmRecording.actions)
        }
    }
        
    private static func validateActionsDidNotChangeDuringReapply(oldActions: [Step],
                                                                 newActions: [Step]) -> StitchAIStepHandlingError? {
        
        // TODO: why or how is the count changing? What is mutating the `newActions` count?
        assertInDebug(oldActions.count == newActions.count)
        log("oldActions.count: \(oldActions.count)")
        log("newActions.count: \(newActions.count)")
        
        for (oldAction, newAction) in zip(oldActions, newActions) {
            if oldAction != newAction {
                let _oldAction = oldAction.convertToType().value
                let _newAction = newAction.convertToType().value
                
                // Steps
                log("Found unequal actions: oldAction: \(oldAction)")
                log("Found unequal actions: newAction: \(newAction)")
                
                // StepActionables
                log("Found unequal actions: _oldAction: \(_oldAction)")
                log("Found unequal actions: _newAction: \(_newAction)")
                
                fatalErrorIfDebug() // Crash on dev
                return .actionValidationError("Found unequal actions:\n\(_oldAction)\n\(_newAction)")
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


// TODO: move to

extension CanvasItemViewModel {
    @MainActor
    func getHardcodedSize(_ graph: GraphReader) -> CGSize? {
        
        switch self.id {
        
        case .node(let nodeId):
            if let patchNode = graph.getNode(nodeId)?.patchNode {
                return PatchOrLayerSizes.patches[patchNode.patch]?[patchNode.userVisibleType]
            } else {
                return nil
            }
        
        case .layerInput(let layerInputCoordinate):
            switch layerInputCoordinate.keyPath.portType {
            case .packed:
                return PatchOrLayerSizes.layerInputs[layerInputCoordinate.keyPath.layerInput]
            case .unpacked:
                return PatchOrLayerSizes.layerFieldSize
            }
            
        case .layerOutput(_):
            return PatchOrLayerSizes.layerOutputSize
        }
    }
}
