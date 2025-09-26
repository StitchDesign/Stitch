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
    var canvasItemIndex = 0  // Counter for Y-offset staggering
    let canvasItemVerticalStagger: CGFloat = 80.0

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
                    log("  ♻️ Restoring packed position for \(inputDefinition.label): \(preservedPosition)")
                    canvas.position = preservedPosition
                } else {
                    let basePosition = updateCanvasPosition(.layerInput(.init(
                        node: nodeId,
                        keyPath: .init(layerInput: inputDefinition, portType: .packed)
                    )))
                    // Add Y-offset staggering to prevent canvas items from stacking
                    let staggeredPosition = CGPoint(
                        x: basePosition.x,
                        y: basePosition.y + CGFloat(canvasItemIndex) * canvasItemVerticalStagger
                    )
                    log("  🆕 New packed position for \(inputDefinition.label): \(basePosition) → staggered: \(staggeredPosition)")
                    canvas.position = staggeredPosition
                    canvasItemIndex += 1
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
                        log("  ♻️ Restoring unpacked[\(index)] position for \(inputDefinition.label): \(preservedPosition)")
                        canvas.position = preservedPosition
                    } else {
                        let basePosition = updateCanvasPosition(.layerInput(.init(
                            node: nodeId,
                            keyPath: .init(layerInput: inputDefinition, portType: .unpacked(index.asUnpackedPortType))
                        )))
                        // Add Y-offset staggering to prevent canvas items from stacking
                        let staggeredPosition = CGPoint(
                            x: basePosition.x,
                            y: basePosition.y + CGFloat(canvasItemIndex) * canvasItemVerticalStagger
                        )
                        log("  🆕 New unpacked[\(index)] position for \(inputDefinition.label): \(basePosition) → staggered: \(staggeredPosition)")
                        canvas.position = staggeredPosition
                        canvasItemIndex += 1
                    }
                    unpackedData.canvasItem = canvas
                }
                return unpackedData
            }
        }

        layerNodeEntity[keyPath: inputDefinition.schemaPortKeyPath] = portData
    }
}

// MARK: - Simple Helper Functions for Node Positioning

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
        log("🚀 Positioning \(self.count) nodes at \(Int(viewPortCenter.x)),\(Int(viewPortCenter.y))")

        // TODO: if we have a chain of nodes, shift our starting point further west
        //    var viewPortCenter = viewPortCenter
        //    viewPortCenter.x -= 500 // We actually shift left a little bit, so nodes look like they're crawling from left to right

        // Horizontal spacing between depth‑columns (increased to prevent nodes from touching)
        let horizontalPadding: CGFloat = 200.0

        let (depthMap, hasCycle) = Stitch.calculateAINodesAdjacency(nodes: self) // patchData.calculateAINodesAdjacency()

        guard let depthMap = depthMap else {
            // log("positionAIGeneratedNodesDuringApply: DID NOT HAVE A depthMap")
            return self
        }

        guard !hasCycle else {
            // log("positionAIGeneratedNodesDuringApply: HAD A CYCLE for depthMap \(depthMap)")
            return self
        }

        // DEBUG: Show depth assignment for each node
        log("🗺️ Depth assignments:")
        for (nodeId, depth) in depthMap {
            if let node = self.getNode(nodeId) {
                log("   Node \(node.title) (\(nodeId.debugFriendlyId)): depth \(depth)")
            }
        }

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
            log("🏗️ Depth \(depth): cumulative xOffset=\(runningX), columnWidth=\(columnWidths[depth] ?? 0)")
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

        // Position nodes within each depth level, starting from row 0 for each depth
        // No global accumulation across depth levels

        // Iterate by depth-level, so that nodes at same depth (e.g. 0) can be y-offset from each other
        let updatedNodes = depthLevels.flatMap { depthLevel -> [NodeEntity] in

            // log("positionAIGeneratedNodesDuringApply: on depthLevel: \(depthLevel)")

            // ───────── vertical layout helpers ─────────
            let verticalPadding: CGFloat = 100.0  // Increased padding to prevent stacking
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
                let calculatedRowHeight = maxH + verticalPadding
                log("📏 Depth \(depthLevel): rowHeight=\(calculatedRowHeight), verticalPadding=\(verticalPadding), maxH=\(maxH)")
                return calculatedRowHeight
            }()

            // Find all the created-nodes at this depth-level
            let createdNodesAtThisLevel: [NodeEntity] = createdNodes.compactMap {
                if depthMap.get($0) == depthLevel {
                    return self.getNode($0)
                }
                return nil
            }

            // Sort nodes at this depth level by their ID for deterministic ordering
            let sortedNodesAtLevel = createdNodesAtThisLevel.sorted { $0.id.uuidString < $1.id.uuidString }

            // Check which nodes are true root nodes (no upstream connections)
            let rootNodes = sortedNodesAtLevel.filter { node in
                node.inputs.allSatisfy { input in
                    if case .upstreamConnection = input { return false }
                    return true
                }
            }

            if !rootNodes.isEmpty {
                let rootTitles = rootNodes.map { $0.title }.joined(separator: ", ")
                log("🌳 Root nodes at depth \(depthLevel): \(rootTitles)")
            }

            // Process nodes at this depth level with pure topological ordering
            var rowCounter = 0
            let processedNodes = sortedNodesAtLevel.map { createdNode in
                var createdNode = createdNode
                let currentRow = rowCounter
                rowCounter += 1

                log("📍 Assigning row \(currentRow) to \(createdNode.title) (\(createdNode.id.debugFriendlyId))")

                let updateCanvasPosition = { (canvasId: CanvasItemId) -> CGPoint in
                    var size: CGSize = canvasId
                        .getHardcodedSize(kind: createdNode.kind,
                                          nodeType: createdNode.nodeTypeEntity.patchNodeEntity?.userVisibleType) ?? CGSize(width: CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER,
                              height: CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER)

                    // Add horizontal gap only
                    size.width += horizontalPadding

                    let cumulativeX = cumulativeXOffset[depthLevel] ?? 0
                    let baseX = viewPortCenter.x + centeringOffset + cumulativeX

                    // Calculate Y position - use baseline for root nodes, row offset for others
                    let baseY = if depthLevel == 0 && rootNodes.contains(where: { $0.id == createdNode.id }) {
                        viewPortCenter.y  // Root nodes at baseline
                    } else {
                        viewPortCenter.y + CGFloat(currentRow) * rowHeight + yOffset
                    }

                    let newPosition = CGPoint(x: baseX, y: baseY)
                    log("📐 \(createdNode.title): x=\(baseX) (depth \(depthLevel)), y=\(baseY) (row \(currentRow), isRoot: \(rootNodes.contains(where: { $0.id == createdNode.id })))")

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

            // Summary logging for this depth level
            log("📊 Depth \(depthLevel) summary: \(processedNodes.count) nodes positioned")

            if !processedNodes.isEmpty {
                let nodePositions = processedNodes.compactMap { node -> String? in
                    switch node.nodeTypeEntity {
                    case .patch(let patchEntity):
                        let pos = patchEntity.canvasEntity.position
                        return "\(node.title):(\(Int(pos.x)),\(Int(pos.y)))"
                    case .layer:
                        return "\(node.title):(layer)"
                    default:
                        return "\(node.title):(other)"
                    }
                }.joined(separator: ", ")
                log("   Final positions: \(nodePositions)")
            }

            return processedNodes
        }
        
        // Log final positioning results summary
        let finalPositions = updatedNodes.compactMap { node -> String? in
            if case .patch(let patchEntity) = node.nodeTypeEntity {
                let pos = patchEntity.canvasEntity.position
                return "\(patchEntity.patch):(\(Int(pos.x)),\(Int(pos.y)))"
            } else if case .layer(let layerEntity) = node.nodeTypeEntity {
                return "\(layerEntity.layer):\(layerEntity.debugPositionString)"
            }
            return nil
        }.joined(separator: ", ")

        log("🚀 Positioned: \(finalPositions)")

        return updatedNodes
    }
}
