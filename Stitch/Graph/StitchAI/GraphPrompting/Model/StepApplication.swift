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
//        positionAIGeneratedNodes(convertedActions: convertedActions,
//                                 nodes: self.visibleGraph.visibleNodesViewModel,
//                                 viewPortCenter: self.newCanvasItemInsertionLocation,
//                                 graph: graph)
        
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
            oldGraphEntity: self.llmRecording.initialGraphState ?? .createEmpty(),
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

// MARK: - Pure Functions for Layer Canvas Item Restoration

/// Restores canvas item positions for a layer node from preserved position data
/// - Parameters:
///   - layerNodeEntity: The layer node to update (modified in place)
///   - nodeId: The node's UUID for coordinate matching
///   - preservedPositions: Previously captured canvas item positions
///   - updateCanvasPosition: Closure to apply new positions to canvas items
private func restoreLayerCanvasItemPositions(
    in layerNodeEntity: inout LayerNodeEntity,
    nodeId: UUID,
    preservedPositions: [LayerCanvasItemCoordinate: CGPoint],
    updateCanvasPosition: (CanvasItemId) -> CGPoint
) {
    for inputDefinition in layerNodeEntity.layer.layerGraphNode.inputDefinitions {
        var portData = layerNodeEntity[keyPath: inputDefinition.schemaPortKeyPath]

        switch portData.mode {
        case .packed:
            if var canvas = portData.packedData.canvasItem {
                let coordinate = LayerCanvasItemCoordinate(
                    nodeId: nodeId,
                    port: inputDefinition,
                    mode: .packed
                )

                if let preservedPosition = preservedPositions[coordinate] {
                    // log("  ♻️ Restoring packed position for \(inputDefinition): \(preservedPosition)")
                    canvas.position = preservedPosition
                } else {
                    let newPosition = updateCanvasPosition(.layerInput(.init(
                        node: nodeId,
                        keyPath: .init(layerInput: inputDefinition, portType: .packed)
                    )))
                    // log("  🆕 New packed position for \(inputDefinition): \(newPosition)")
                    canvas.position = newPosition
                }
                portData.packedData.canvasItem = canvas
            }

        case .unpacked:
            portData.unpackedData = portData.unpackedData.enumerated().map { (index, unpackedData) in
                var unpackedData = unpackedData
                if var canvas = unpackedData.canvasItem {
                    let coordinate = LayerCanvasItemCoordinate(
                        nodeId: nodeId,
                        port: inputDefinition,
                        mode: .unpacked(index: index)
                    )

                    if let preservedPosition = preservedPositions[coordinate] {
                        // log("  ♻️ Restoring unpacked[\(index)] position for \(inputDefinition): \(preservedPosition)")
                        canvas.position = preservedPosition
                    } else {
                        let newPosition = updateCanvasPosition(.layerInput(.init(
                            node: nodeId,
                            keyPath: .init(layerInput: inputDefinition, portType: .unpacked(index.asUnpackedPortType))
                        )))
                        // log("  🆕 New unpacked[\(index)] position for \(inputDefinition): \(newPosition)")
                        canvas.position = newPosition
                    }
                    unpackedData.canvasItem = canvas
                }
                return unpackedData
            }
        }

        layerNodeEntity[keyPath: inputDefinition.schemaPortKeyPath] = portData
    }
}

extension Array where Element == NodeEntity {
    func getNode(_ id: UUID) -> NodeEntity? {
        self.first { $0.id == id }
    }

    @MainActor
    func positionAIGeneratedNodesDuringApply(
        viewPortCenter: CGPoint,
        existingNodes: [NodeEntity],
        matchedNodeIds: Set<UUID> = [],
        layerCanvasItemPositions: [LayerCanvasItemCoordinate: CGPoint] = [:]
    ) -> Self {
        log("🚀 positionAIGeneratedNodesDuringApply called:")
        log("🚀   Input nodes: \(self.count)")
        log("🚀   ViewPort center: \(viewPortCenter)")
        log("🚀   Existing nodes: \(existingNodes.count)")
        log("🚀   Matched nodes: \(matchedNodeIds.count) - \(matchedNodeIds)")
        log("🚀   Layer canvas positions: \(layerCanvasItemPositions.count)")

        // Log all input node positions
        for node in self {
            if case .patch(let patchEntity) = node.nodeTypeEntity {
                log("🚀   Input patch node \(node.id): \(patchEntity.patch) at \(patchEntity.canvasEntity.position)")
            } else if case .layer(let layerEntity) = node.nodeTypeEntity {
                log("🚀   Input layer node \(node.id): \(layerEntity.layer) at \(layerEntity.debugPositionString)")
            }
        }

        // TODO: if we have a chain of nodes, shift our starting point further west
        //    var viewPortCenter = viewPortCenter
        //    viewPortCenter.x -= 500 // We actually shift left a little bit, so nodes look like they're crawling from left to right

        // Horizontal spacing between depth‑columns
        let horizontalPadding: CGFloat = 120.0

        let (depthMap, hasCycle) = Stitch.calculateAINodesAdjacency(nodes: self) // patchData.calculateAINodesAdjacency()

        guard let depthMap = depthMap else {
            // log("positionAIGeneratedNodesDuringApply: DID NOT HAVE A depthMap")
            return self
        }

        guard !hasCycle else {
            // log("positionAIGeneratedNodesDuringApply: HAD A CYCLE for depthMap \(depthMap)")
            return self
        }

        // log("positionAIGeneratedNodesDuringApply: depthMap: \(depthMap)")

        guard !depthMap.isEmpty else {
            //        fatalErrorIfDebug("Depth-map should never be empty")
            // log("positionAIGeneratedNodesDuringApply: Depth-map should never be empty") // can be empty if we have no nodes
            return self
        }

        let depthLevels = depthMap.values.sorted().toOrderedSet

        let createdNodes: IdSet = self.map(\.id).toSet

        // Determine widest item (incl. padding) for each depth column
        var columnWidths: [Int: CGFloat] = [:]
        depthLevels.forEach { depth in
            let nodesAtLevel = createdNodes.compactMap { depthMap.get($0) == depth ? self.getNode($0) : nil }
            let maxWidth = nodesAtLevel.flatMap { node in
                node.canvasIds.compactMap { canvasId in
                    (canvasId.getHardcodedSize(kind: node.kind,
                                               nodeType: node.nodeTypeEntity.patchNodeEntity?.userVisibleType)?.width ??
                     CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER) + horizontalPadding
                }
            }.max() ?? (CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER + horizontalPadding)
            columnWidths[depth] = maxWidth
        }

        // Build cumulative X offsets so each column starts after the previous one
        var cumulativeXOffset: [Int: CGFloat] = [:]
        var runningX: CGFloat = 0
        depthLevels.sorted().forEach { depth in
            cumulativeXOffset[depth] = runningX
            runningX += columnWidths[depth] ?? 0
        }

        // Calculate centering offset to position the middle of the chain at viewport center
        let totalChainWidth = runningX
        let centeringOffset = -totalChainWidth / 2.0
        // log("🎯 Chain centering: totalWidth=\(totalChainWidth), centeringOffset=\(centeringOffset)")

        // COLLISION DETECTION: Get existing nodes near viewport (exclude newly created nodes)
        let searchRadius: CGFloat = 1500.0
        let nearbyExistingNodes = existingNodes.filter { existingNode in
            // Exclude the new nodes we're trying to position
            if createdNodes.contains(existingNode.id) {
                return false
            }

            // Check if node is within search radius of viewport
            if let bounds = self.getNodeBounds(existingNode) {
                let searchArea = CGRect(
                    x: viewPortCenter.x - searchRadius,
                    y: viewPortCenter.y - searchRadius,
                    width: searchRadius * 2,
                    height: searchRadius * 3 // More vertical range for scanning down
                )
                return searchArea.intersects(bounds)
            }

            return false
        }

        // Calculate the total height needed for all new nodes
        let verticalPadding: CGFloat = 80.0
        var totalHeight: CGFloat = 0

        // Calculate max height for each depth level
        depthLevels.forEach { depth in
            let nodesAtLevel = createdNodes.compactMap { depthMap.get($0) == depth ? self.getNode($0) : nil }
            let maxHeight = nodesAtLevel.flatMap { node in
                node.canvasIds.map { canvasId in
                    canvasId.getHardcodedSize(
                        kind: node.kind,
                        nodeType: node.nodeTypeEntity.patchNodeEntity?.userVisibleType)?.height ?? CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER
                }
            }.max() ?? CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER

            let nodeCount = nodesAtLevel.count
            totalHeight += CGFloat(nodeCount) * (maxHeight + verticalPadding)
        }

        // Create bounds for the entire new node cluster
        let newNodesBounds = CGRect(
            x: viewPortCenter.x + centeringOffset,
            y: viewPortCenter.y,
            width: totalChainWidth,
            height: totalHeight
        )

        // Check for collisions and find clear Y position if needed
        let clearY = self.findClearYPosition(
            startY: viewPortCenter.y,
            newNodesBounds: newNodesBounds,
            nearbyNodes: nearbyExistingNodes
        ) ?? viewPortCenter.y

        // Calculate Y offset to apply to all positions
        let yOffset = clearY - viewPortCenter.y

        if yOffset != 0 {
            log("🔄 AI nodes repositioned: Moving \(yOffset) points down to avoid overlaps")
        }

        // Iterate by depth-level, so that nodes at same depth (e.g. 0) can be y-offset from each other
        let updatedNodes = depthLevels.flatMap { depthLevel -> [NodeEntity] in
            
            // log("positionAIGeneratedNodesDuringApply: on depthLevel: \(depthLevel)")
            
            // ───────── vertical layout helpers ─────────
            let verticalPadding: CGFloat = 80.0
            // Tallest observer at this depth
            let rowHeight: CGFloat = {
                let maxH = createdNodes.compactMap { depthMap.get($0) == depthLevel ? self.getNode($0) : nil }
                    .flatMap { node in
                        node.canvasIds
                            .map { canvasId in
                                canvasId
                                    .getHardcodedSize(
                                        kind: node.kind,
                                        nodeType: node.nodeTypeEntity.patchNodeEntity?.userVisibleType)?.height ?? CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER
                            }
                    }
                    .max() ?? CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER
                return maxH + verticalPadding
            }()
            var rowIndexForDepth = 0
            
            // TODO: just rewrite the adjacency // logic to be a mapping of [Int: [UUID]] instead of [UUID: Int]
            // Find all the created-nodes at this depth-level,
            // and adjust their positions
            let createdNodesAtThisLevel: [NodeEntity] = createdNodes.compactMap {
                if depthMap.get($0) == depthLevel {
                    return self.getNode($0)
                }
                // THIS JUST MEANS WE COULD NOT FIND THE NODE AT THIS LEVEL
                 // log("positionAIGeneratedNodesDuringApply: Could not get depth level for \($0.debugFriendlyId)")
                return nil
            }
            
            return createdNodesAtThisLevel.map { createdNode in
                var createdNode = createdNode

                // log("positionAIGeneratedNodesDuringApply: on createdNode \(createdNode.id) \(createdNode.kind)")

                let isNodeMatched = matchedNodeIds.contains(createdNode.id)

                // Skip positioning for matched PATCH nodes only - layer nodes need canvas item handling
                if isNodeMatched && createdNode.nodeTypeEntity.patchNodeEntity != nil {
                    // log("⏭️ Skipping positioning for matched patch node \(createdNode.id)")
                    return createdNode
                }
                
                let updateCanvasPosition = { (canvasId: CanvasItemId) -> CGPoint in
                    var size: CGSize = canvasId
                        .getHardcodedSize(kind: createdNode.kind,
                                          nodeType: createdNode.nodeTypeEntity.patchNodeEntity?.userVisibleType) ?? CGSize(width: CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER,
                              height: CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER)

                    // Add horizontal gap only
                    size.width += horizontalPadding

                    let newPosition = CGPoint(
                        x: viewPortCenter.x + centeringOffset + (cumulativeXOffset[depthLevel] ?? 0),
                        y: viewPortCenter.y + CGFloat(rowIndexForDepth) * rowHeight + yOffset  // Apply collision avoidance offset
                    )
                    rowIndexForDepth += 1

                    // // log("positionAIGeneratedNodes: size for \(canvasItem.id): \(String(describing: size))")
                    // log("positionAIGeneratedNodesDuringApply: newPosition: \(newPosition)")
                    return newPosition
                }

                switch createdNode.nodeTypeEntity {
                case .patch(var patchNode):
                    patchNode.canvasEntity.position = updateCanvasPosition(
                        .node(createdNode.id)
                    )
                    createdNode.nodeTypeEntity = .patch(patchNode)
                    
                case .layer(var layerNodeEntity):
                    let isLayerMatched = matchedNodeIds.contains(createdNode.id)
                    // log("🎯 Processing layer \(createdNode.id), matched: \(isLayerMatched)")

                    // Use pure function to restore canvas item positions
                    restoreLayerCanvasItemPositions(
                        in: &layerNodeEntity,
                        nodeId: createdNode.id,
                        preservedPositions: layerCanvasItemPositions,
                        updateCanvasPosition: updateCanvasPosition
                    )

                    createdNode.nodeTypeEntity = .layer(layerNodeEntity)
                
                case .group(var canvasEntity):
                    canvasEntity.position = updateCanvasPosition(
                        .node(createdNode.id)
                    )
                    
                    createdNode.nodeTypeEntity = .group(canvasEntity)
                
                case .component(var component):
                    component.canvasEntity.position = updateCanvasPosition(
                        .node(createdNode.id)
                    )
                    
                    createdNode.nodeTypeEntity = .component(component)
                }
                
                return createdNode
            }
        }
        
        // Log final positioning results
        log("🚀 positionAIGeneratedNodesDuringApply completed:")
        log("🚀   Output nodes: \(updatedNodes.count)")

        for node in updatedNodes {
            if case .patch(let patchEntity) = node.nodeTypeEntity {
                log("🚀   Final patch node \(node.id): \(patchEntity.patch) at \(patchEntity.canvasEntity.position)")
            } else if case .layer(let layerEntity) = node.nodeTypeEntity {
                log("🚀   Final layer node \(node.id): \(layerEntity.layer) at \(layerEntity.debugPositionString)")
            }
        }

        return updatedNodes
    }
}
