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
private func positionLayerCanvasItems(
    in layerNodeEntity: inout LayerNodeEntity,
    nodeId: UUID,
    updateCanvasPosition: (CanvasItemId) -> CGPoint
) {
    for inputDefinition in layerNodeEntity.layer.layerGraphNode.inputDefinitions {
        var portData = layerNodeEntity[keyPath: inputDefinition.schemaPortKeyPath]

        switch portData.mode {
        case .packed:
            if var canvas = portData.packedData.canvasItem {
//                let coordinate = LayerCanvasItemCoordinate(
//                    nodeId: nodeId,
//                    port: inputDefinition,
//                    mode: .packed
//                )

                let newPosition = updateCanvasPosition(.layerInput(.init(
                    node: nodeId,
                    keyPath: .init(layerInput: inputDefinition, portType: .packed)
                )))
                // log("  🆕 New packed position for \(inputDefinition): \(newPosition)")
                canvas.position = newPosition
                portData.packedData.canvasItem = canvas
            }

        case .unpacked:
            portData.unpackedData = portData.unpackedData.enumerated().map { (index, unpackedData) in
                var unpackedData = unpackedData
                if var canvas = unpackedData.canvasItem {
//                    let coordinate = LayerCanvasItemCoordinate(
//                        nodeId: nodeId,
//                        port: inputDefinition,
//                        mode: .unpacked(index: index)
//                    )

                    let newPosition = updateCanvasPosition(.layerInput(.init(
                        node: nodeId,
                        keyPath: .init(layerInput: inputDefinition, portType: .unpacked(index.asUnpackedPortType))
                    )))
                    // log("  🆕 New unpacked[\(index)] position for \(inputDefinition): \(newPosition)")
                    canvas.position = newPosition
                    unpackedData.canvasItem = canvas
                }
                return unpackedData
            }
        }

        layerNodeEntity[keyPath: inputDefinition.schemaPortKeyPath] = portData
    }
}

// MARK: - Optimized Node Positioning

/// Cache for pre-computed node sizing data to avoid repeated calculations
private struct NodeSizeCache {
    let size: CGSize
    let canvasIds: [CanvasItemId]
    let nodeType: NodeType?
    let kind: NodeKind
}

/// Pre-computed layout data for a depth level
private struct DepthLevelLayout {
    let depth: Int
    let nodes: [NodeEntity]
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let rowHeight: CGFloat
    let cumulativeXOffset: CGFloat
}

extension Array where Element == NodeEntity {
    func getNode(_ id: UUID) -> NodeEntity? {
        self.first { $0.id == id }
    }

    func positionAIGeneratedNodesDuringApply(
        viewPortCenter: CGPoint) -> Self {

        // Performance instrumentation - start timing
        let startTime = CFAbsoluteTimeGetCurrent()

        // Constants
        let horizontalPadding: CGFloat = 120.0
        let verticalPadding: CGFloat = 80.0

        // Early validation and adjacency calculation
        let (depthMap, hasCycle) = Stitch.calculateAINodesAdjacency(nodes: self)

        guard let depthMap = depthMap, !hasCycle, !depthMap.isEmpty else {
            return self
        }

        // Pre-compute all node sizes once to avoid repeated lookups
        let nodeSizeCache: [UUID: NodeSizeCache] = self.reduce(into: [:]) { cache, node in
            let nodeType = node.nodeTypeEntity.patchNodeEntity?.userVisibleType
            cache[node.id] = NodeSizeCache(
                size: node.canvasIds.first?.getHardcodedSize(kind: node.kind, nodeType: nodeType) ??
                      CGSize(width: CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER,
                             height: CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER),
                canvasIds: node.canvasIds,
                nodeType: nodeType,
                kind: node.kind
            )
        }

        // Group nodes by depth level efficiently (single pass)
        let nodesByDepth: [Int: [NodeEntity]] = Dictionary(grouping: self) { node in
            depthMap[node.id] ?? 0
        }

        let sortedDepths = nodesByDepth.keys.sorted()

        // Pre-compute layout data for each depth level
        var depthLayouts: [DepthLevelLayout] = []
        var runningX: CGFloat = 0

        for depth in sortedDepths {
            guard let nodesAtLevel = nodesByDepth[depth] else { continue }

            // Calculate max dimensions for this depth level
            let maxWidth = nodesAtLevel.compactMap { node in
                nodeSizeCache[node.id]?.size.width
            }.max() ?? CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER

            let maxHeight = nodesAtLevel.compactMap { node in
                nodeSizeCache[node.id]?.size.height
            }.max() ?? CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER

            let layout = DepthLevelLayout(
                depth: depth,
                nodes: nodesAtLevel,
                maxWidth: maxWidth + horizontalPadding,
                maxHeight: maxHeight,
                rowHeight: maxHeight + verticalPadding,
                cumulativeXOffset: runningX
            )

            depthLayouts.append(layout)
            runningX += layout.maxWidth
        }

        // Calculate centering offset
        let totalChainWidth = runningX
        let centeringOffset = -totalChainWidth / 2.0

        // Apply positions to all nodes (flattened single pass)
        let updatedNodes = depthLayouts.flatMap { layout -> [NodeEntity] in
            var rowIndex = 0

            return layout.nodes.map { node in
                var updatedNode = node
                guard let sizeCache = nodeSizeCache[node.id] else { return node }

                // Pre-calculated position for this node
                let basePosition = CGPoint(
                    x: viewPortCenter.x + centeringOffset + layout.cumulativeXOffset,
                    y: viewPortCenter.y + CGFloat(rowIndex) * layout.rowHeight
                )
                rowIndex += 1

                // Optimized position update closure
                let updateCanvasPosition = { (canvasId: CanvasItemId) -> CGPoint in
                    basePosition
                }

                // Apply positions based on node type
                updateNodePositions(
                    node: &updatedNode,
                    sizeCache: sizeCache,
                    updateCanvasPosition: updateCanvasPosition
                )

                return updatedNode
            }
        }

        // Performance instrumentation - end timing
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds

        // Log performance metrics
        // log("🚀 positionAIGeneratedNodesDuringApply: \(self.count) nodes positioned in \(String(format: "%.2f", executionTime))ms")

        return updatedNodes
    }

    /// Optimized helper function to update node positions based on type
    private func updateNodePositions(
        node: inout NodeEntity,
        sizeCache: NodeSizeCache,
        updateCanvasPosition: (CanvasItemId) -> CGPoint
    ) {
        switch node.nodeTypeEntity {
        case .patch(var patchNode):
            patchNode.canvasEntity.position = updateCanvasPosition(.node(node.id))
            node.nodeTypeEntity = .patch(patchNode)

        case .layer(var layerNodeEntity):
            positionLayerCanvasItems(
                in: &layerNodeEntity,
                nodeId: node.id,
                updateCanvasPosition: updateCanvasPosition
            )
            node.nodeTypeEntity = .layer(layerNodeEntity)

        case .group(var canvasEntity):
            canvasEntity.position = updateCanvasPosition(.node(node.id))
            node.nodeTypeEntity = .group(canvasEntity)

        case .component(var component):
            component.canvasEntity.position = updateCanvasPosition(.node(node.id))
            node.nodeTypeEntity = .component(component)
        }
    }
    
    // Infers sidebar data given existing set of nodes
//    func createOrderedSidebarData() -> SidebarLayerList {
//        // First create dictionary of group ID to ordered list of children
//        let layerGroupToChildren = self.reduce(into: [UUID? : [UUID]]()) { result, node in
//            guard let layerNode = node.layerNodeEntity else {
//                return
//            }
//            
//            var existingList = result.get(layerNode.layerGroupId) ?? []
//            existingList.append(node.id)
//            result.updateValue(existingList, forKey: layerNode.layerGroupId)
//        }
//        
//        let rootList = layerGroupToChildren[nil] ?? []
//        return rootList.inferSidebarData(using: layerGroupToChildren)
//    }
}

//extension Array where Element == UUID {
//    func inferSidebarData(using layerGroupToChildren: [UUID? : [UUID]]) -> SidebarLayerList {
//        self.map { layerId in
//            // If not a group, return entry
//            guard let groupList = layerGroupToChildren.get(layerId) else {
//                return .init(id: layerId, children: nil)
//            }
//            
//            let children = groupList.inferSidebarData(using: layerGroupToChildren)
//            return .init(id: layerId, children: children)
//        }
//    }
//}
