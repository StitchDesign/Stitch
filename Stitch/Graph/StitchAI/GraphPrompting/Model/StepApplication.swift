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

// MARK: - Topological Insertion System

struct TopologicalRelationship {
    let newNode: UUID
    let upstreamOf: Set<UUID>      // Nodes that depend on this new node
    let downstreamOf: Set<UUID>    // Nodes this new node depends on
    let parallelTo: Set<UUID>      // Independent nodes at same depth
    let insertionStrategy: InsertionStrategy
}

enum InsertionStrategy {
    case westInsert(shiftNodes: Set<UUID>, shiftAmount: CGFloat)
    case eastAppend(afterNode: UUID?)
    case depthInsert(atDepth: Int, position: Int)
}

struct PositionRegistry {
    var preservedPositions: [UUID: CGPoint] = [:]
    var affectedNodes: Set<UUID> = []

    func shouldPreserve(_ nodeId: UUID) -> Bool {
        return !affectedNodes.contains(nodeId)
    }
}

// MARK: - Topological Analysis Functions

private func analyzeTopologicalRelationships(
    newNode: NodeEntity,
    existingNodes: [NodeEntity],
    depthMap: [UUID: Int]
) -> TopologicalRelationship {
    var upstreamOf: Set<UUID> = []
    var downstreamOf: Set<UUID> = []
    var parallelTo: Set<UUID> = []

    let newNodeDepth = depthMap[newNode.id] ?? 0
    log("🔍 TOPO-ANALYSIS: Starting analysis for \(newNode.title) at depth \(newNodeDepth)")

    // Analyze each existing node's relationship to new node
    for existingNode in existingNodes {
        let existingDepth = depthMap[existingNode.id] ?? 0

        if feeds(newNode, into: existingNode) {
            upstreamOf.insert(existingNode.id)
            log("  → \(newNode.title) feeds into \(existingNode.title) (depth \(existingDepth))")
        } else if feeds(existingNode, into: newNode) {
            downstreamOf.insert(existingNode.id)
            log("  ← \(existingNode.title) feeds into \(newNode.title) (depth \(existingDepth))")
        } else if existingDepth == newNodeDepth {
            parallelTo.insert(existingNode.id)
            log("  ↔ \(newNode.title) parallel to \(existingNode.title) (both depth \(existingDepth))")
        } else {
            log("  ⊗ \(newNode.title) independent of \(existingNode.title) (depths: \(newNodeDepth) vs \(existingDepth))")
        }
    }

    // Determine insertion strategy based on relationships
    let strategy: InsertionStrategy
    log("📋 TOPO-STRATEGY: Selecting insertion strategy for \(newNode.title)")
    log("   Feeds into \(upstreamOf.count) nodes, fed by \(downstreamOf.count) nodes, parallel to \(parallelTo.count) nodes")

    if !upstreamOf.isEmpty {
        // New node feeds into existing nodes - insert west and shift them east
        let shiftAmount: CGFloat = 250.0 // Node width + padding
        strategy = .westInsert(shiftNodes: upstreamOf, shiftAmount: shiftAmount)
        log("   ✅ Selected westInsert: shift \(upstreamOf.count) downstream nodes east by \(shiftAmount)")
        let nodesToShift = upstreamOf.compactMap { nodeId in
            existingNodes.first { $0.id == nodeId }?.title
        }.joined(separator: ", ")
        log("      Nodes to shift: \(nodesToShift)")
    } else if !downstreamOf.isEmpty {
        // New node depends on existing nodes - append to east
        let eastmostNode = findEastmostNode(in: downstreamOf, existingNodes: existingNodes)
        strategy = .eastAppend(afterNode: eastmostNode)
        let eastmostTitle = existingNodes.first { $0.id == eastmostNode }?.title ?? "Unknown"
        log("   ✅ Selected eastAppend: position after eastmost upstream node \(eastmostTitle)")
    } else {
        // Parallel node - insert at appropriate position within depth level
        strategy = .depthInsert(atDepth: newNodeDepth, position: parallelTo.count)
        log("   ✅ Selected depthInsert: position \(parallelTo.count) at depth \(newNodeDepth)")
    }

    return TopologicalRelationship(
        newNode: newNode.id,
        upstreamOf: upstreamOf,
        downstreamOf: downstreamOf,
        parallelTo: parallelTo,
        insertionStrategy: strategy
    )
}

private func feeds(_ sourceNode: NodeEntity, into targetNode: NodeEntity) -> Bool {
    // Check if sourceNode's output feeds into any of targetNode's inputs
    switch targetNode.nodeTypeEntity {
    case .patch(let patchEntity):
        return patchEntity.inputs.contains { input in
            if case .upstreamConnection(let coordinate) = input.portData {
                return coordinate.nodeId == sourceNode.id
            }
            return false
        }
    case .layer(let layerEntity):
        // Check layer input connections
        for inputDefinition in layerEntity.layer.layerGraphNode.inputDefinitions {
            let portData = layerEntity[keyPath: inputDefinition.schemaPortKeyPath]

            switch portData.mode {
            case .packed:
                if case .upstreamConnection(let coordinate) = portData.packedData.inputPort {
                    if coordinate.nodeId == sourceNode.id {
                        return true
                    }
                }
            case .unpacked:
                for unpackedData in portData.unpackedData {
                    if case .upstreamConnection(let coordinate) = unpackedData.inputPort {
                        if coordinate.nodeId == sourceNode.id {
                            return true
                        }
                    }
                }
            }
        }
        return false
    case .group, .component:
        return false
    }
}

private func findEastmostNode(in nodeIds: Set<UUID>, existingNodes: [NodeEntity]) -> UUID? {
    // For now, return the first node. In full implementation, would find eastmost positioned node
    return nodeIds.first
}

private func applyEastwardShift(to node: NodeEntity, shiftAmount: CGFloat) {
    switch node.nodeTypeEntity {
    case .patch(let patchEntity):
        let currentPosition = patchEntity.canvasEntity.position
        let newPosition = CGPoint(
            x: currentPosition.x + shiftAmount,
            y: currentPosition.y
        )
        log("    ↗️ Shifting \(node.title) from \(currentPosition.x) to \(newPosition.x)")

        // Note: This only logs the intended shift. The actual position update would need
        // to be applied to the node entity in the graph state

    case .layer(let layerEntity):
        // Handle layer canvas items if they exist
        for inputDef in layerEntity.layer.layerGraphNode.inputDefinitions {
            let portData = layerEntity[keyPath: inputDef.schemaPortKeyPath]

            switch portData.mode {
            case .packed:
                if let canvas = portData.packedData.canvasItem {
                    let currentPos = canvas.position
                    let newPos = CGPoint(x: currentPos.x + shiftAmount, y: currentPos.y)
                    log("    ↗️ Shifting layer \(node.title) canvas item \(inputDef.label) from \(currentPos.x) to \(newPos.x)")
                }
            case .unpacked:
                for (index, unpackedData) in portData.unpackedData.enumerated() {
                    if let canvas = unpackedData.canvasItem {
                        let currentPos = canvas.position
                        let newPos = CGPoint(x: currentPos.x + shiftAmount, y: currentPos.y)
                        log("    ↗️ Shifting layer \(node.title) unpacked[\(index)] \(inputDef.label) from \(currentPos.x) to \(newPos.x)")
                    }
                }
            }
        }

    case .group(let canvasEntity):
        let currentPosition = canvasEntity.position
        let newPosition = CGPoint(
            x: currentPosition.x + shiftAmount,
            y: currentPosition.y
        )
        log("    ↗️ Shifting group \(node.title) from \(currentPosition.x) to \(newPosition.x)")

    case .component(let componentEntity):
        let currentPosition = componentEntity.canvasEntity.position
        let newPosition = CGPoint(
            x: currentPosition.x + shiftAmount,
            y: currentPosition.y
        )
        log("    ↗️ Shifting component \(node.title) from \(currentPosition.x) to \(newPosition.x)")
    }
}

private func hasValidPosition(_ node: NodeEntity) -> Bool {
    switch node.nodeTypeEntity {
    case .patch(let patchEntity):
        return patchEntity.canvasEntity.position != CGPoint.zero

    case .layer(let layerEntity):
        // For layers, check if any canvas items have valid positions
        for inputDef in layerEntity.layer.layerGraphNode.inputDefinitions {
            let portData = layerEntity[keyPath: inputDef.schemaPortKeyPath]

            switch portData.mode {
            case .packed:
                if let canvas = portData.packedData.canvasItem,
                   canvas.position != CGPoint.zero {
                    return true
                }
            case .unpacked:
                for unpackedData in portData.unpackedData {
                    if let canvas = unpackedData.canvasItem,
                       canvas.position != CGPoint.zero {
                        return true
                    }
                }
            }
        }
        return false

    case .group(let canvasEntity):
        return canvasEntity.position != CGPoint.zero

    case .component(let componentEntity):
        return componentEntity.canvasEntity.position != CGPoint.zero
    }
}

private func getPositionString(_ node: NodeEntity) -> String {
    switch node.nodeTypeEntity {
    case .patch(let patchEntity):
        let pos = patchEntity.canvasEntity.position
        return "(\(Int(pos.x)),\(Int(pos.y)))"

    case .layer(let layerEntity):
        var positions: [String] = []
        for inputDef in layerEntity.layer.layerGraphNode.inputDefinitions {
            let portData = layerEntity[keyPath: inputDef.schemaPortKeyPath]

            switch portData.mode {
            case .packed:
                if let canvas = portData.packedData.canvasItem {
                    let pos = canvas.position
                    positions.append("\(inputDef.label):(\(Int(pos.x)),\(Int(pos.y)))")
                }
            case .unpacked:
                for (index, unpackedData) in portData.unpackedData.enumerated() {
                    if let canvas = unpackedData.canvasItem {
                        let pos = canvas.position
                        positions.append("\(inputDef.label)[\(index)]:(\(Int(pos.x)),\(Int(pos.y)))")
                    }
                }
            }
        }
        return positions.joined(separator: ", ")

    case .group(let canvasEntity):
        let pos = canvasEntity.position
        return "(\(Int(pos.x)),\(Int(pos.y)))"

    case .component(let componentEntity):
        let pos = componentEntity.canvasEntity.position
        return "(\(Int(pos.x)),\(Int(pos.y)))"
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
        var loopNodes: [(NodeEntity, Int)] = []
        var layerNodes: [(NodeEntity, Int)] = []

        for (nodeId, depth) in depthMap {
            if let node = self.getNode(nodeId) {
                log("   Node \(node.title) (\(nodeId.debugFriendlyId)): depth \(depth)")

                // Track Loop nodes and Layer nodes for scenario testing
                if case .patch(let patchEntity) = node.nodeTypeEntity,
                   case .loop = patchEntity.patch {
                    loopNodes.append((node, depth))
                } else if case .layer = node.nodeTypeEntity {
                    layerNodes.append((node, depth))
                }
            }
        }

        // LOOP NODE SCENARIO TEST: Verify Loop nodes are positioned upstream of layer nodes they feed
        if !loopNodes.isEmpty && !layerNodes.isEmpty {
            log("🔍 LOOP-SCENARIO-TEST: Analyzing Loop node positioning")
            for (loopNode, loopDepth) in loopNodes {
                log("   Loop node \(loopNode.title) at depth \(loopDepth)")

                // Find layer nodes that this loop feeds into
                let fedLayerNodes = layerNodes.filter { (layerNode, layerDepth) in
                    feeds(loopNode, into: layerNode)
                }

                if !fedLayerNodes.isEmpty {
                    let layerTitles = fedLayerNodes.map { $0.0.title }.joined(separator: ", ")
                    let layerDepths = fedLayerNodes.map { $0.1 }.sorted()
                    log("   → Loop \(loopNode.title) feeds into layers: \(layerTitles)")
                    log("   → Expected: Loop depth (\(loopDepth)) < Layer depths (\(layerDepths))")

                    let isCorrectlyPositioned = fedLayerNodes.allSatisfy { (_, layerDepth) in
                        loopDepth < layerDepth
                    }

                    if isCorrectlyPositioned {
                        log("   ✅ PASS: Loop node correctly positioned upstream")
                    } else {
                        log("   ❌ FAIL: Loop node incorrectly positioned - may cause stacking")
                    }
                }
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
                let calculatedRowHeight = maxH + verticalPadding
                log("🔧 Depth \(depthLevel): rowHeight=\(calculatedRowHeight), verticalPadding=\(verticalPadding), maxH=\(maxH)")
                return calculatedRowHeight
            }()

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

            // TOPOLOGICAL INSERTION: Separate new nodes from existing nodes
            let allExistingNodes = existingNodes.filter { node in
                // Include both nodes that existed before AND nodes created in previous iterations
                !createdNodes.contains(node.id) || (depthMap[node.id] != depthLevel)
            }

            // For each new node at this level, analyze its topological relationships
            var topologicallyOrderedNodes: [NodeEntity] = []
            var positionRegistry = PositionRegistry()

            for newNode in createdNodesAtThisLevel {
                let isNewNode = createdNodes.contains(newNode.id)

                if isNewNode {
                    // Analyze topological relationships for new nodes
                    let relationship = analyzeTopologicalRelationships(
                        newNode: newNode,
                        existingNodes: allExistingNodes + topologicallyOrderedNodes,
                        depthMap: depthMap
                    )

                    log("🔗 TOPO: Analyzing \(newNode.title) (\(newNode.id.debugFriendlyId))")
                    log("  → Feeds into: \(relationship.upstreamOf.map { $0.debugFriendlyId })")
                    log("  → Fed by: \(relationship.downstreamOf.map { $0.debugFriendlyId })")
                    log("  → Strategy: \(relationship.insertionStrategy)")

                    // Add affected nodes to registry
                    switch relationship.insertionStrategy {
                    case .westInsert(let shiftNodes, _):
                        positionRegistry.affectedNodes.formUnion(shiftNodes)
                    case .eastAppend, .depthInsert:
                        break
                    }
                }

                topologicallyOrderedNodes.append(newNode)
            }

            // STEP: Detect position conflicts (anti-stacking logic)
            let currentPositions = createdNodesAtThisLevel.compactMap { node -> CGPoint? in
                return node.nodeTypeEntity.patchNodeEntity?.canvasEntity.position
            }

            // Find positions that appear more than once (conflicts)
            var positionCounts: [CGPoint: Int] = [:]
            currentPositions.forEach { position in
                positionCounts[position] = (positionCounts[position] ?? 0) + 1
            }
            let conflictedPositions = Set(positionCounts.compactMap { (position, count) in
                count > 1 ? position : nil
            })

            if !conflictedPositions.isEmpty {
                log("🚨 Position conflicts detected at depth \(depthLevel): \(conflictedPositions.count) conflicted positions")
            }

            // MINIMAL-DISRUPTION INSERTION: Apply position shifts for westInsert strategies
            for newNode in createdNodesAtThisLevel {
                let isNewNode = createdNodes.contains(newNode.id)

                if isNewNode {
                    let relationship = analyzeTopologicalRelationships(
                        newNode: newNode,
                        existingNodes: allExistingNodes + topologicallyOrderedNodes.filter { $0.id != newNode.id },
                        depthMap: depthMap
                    )

                    switch relationship.insertionStrategy {
                    case .westInsert(let shiftNodes, let shiftAmount):
                        log("🔄 TOPO: Applying westInsert for \(newNode.title) - shifting \(shiftNodes.count) nodes east by \(shiftAmount)")

                        // Apply eastward shift to downstream nodes
                        for nodeId in shiftNodes {
                            if let nodeToShift = allExistingNodes.first(where: { $0.id == nodeId }) {
                                applyEastwardShift(to: nodeToShift, shiftAmount: shiftAmount)
                            }
                        }

                    case .eastAppend, .depthInsert:
                        // No immediate position shifts needed for these strategies
                        break
                    }
                }
            }

            // TOPOLOGICAL POSITIONING: Use topologically ordered nodes instead of arbitrary enumeration
            let processedNodes = topologicallyOrderedNodes.enumerated().map { (nodeIndex, createdNode) in
                var createdNode = createdNode

                // log("positionAIGeneratedNodesDuringApply: on createdNode \(createdNode.id) \(createdNode.kind)")

                let isNodeMatched = matchedNodeIds.contains(createdNode.id)

                // POSITION PRESERVATION: Check if this node should preserve its current position
                if positionRegistry.shouldPreserve(createdNode.id) {
                    // This node is not affected by topological insertions - preserve its position
                    let shouldPreservePosition = hasValidPosition(createdNode)

                    if shouldPreservePosition {
                        let positionString = getPositionString(createdNode)
                        log("✓ TOPO: Preserving position for \(createdNode.title) at \(positionString)")
                        return createdNode
                    } else {
                        log("⚠️ TOPO: Node \(createdNode.title) marked for preservation but has invalid position, proceeding with normal positioning")
                    }
                }

                // Skip positioning for matched PATCH nodes only if they have a unique, valid position
                if isNodeMatched && createdNode.nodeTypeEntity.patchNodeEntity != nil {
                    let currentPosition = createdNode.nodeTypeEntity.patchNodeEntity?.canvasEntity.position ?? CGPoint.zero
                    let hasPositionConflict = conflictedPositions.contains(currentPosition)

                    if currentPosition != CGPoint.zero && !hasPositionConflict {
                        // log("⏭️ Skipping positioning for matched patch node \(createdNode.id) with unique position \(currentPosition)")
                        return createdNode
                    }
                    // log("🔄 Matched patch node \(createdNode.id) has conflicted or zero position, applying repositioning")
                }

                let updateCanvasPosition = { (canvasId: CanvasItemId) -> CGPoint in
                    var size: CGSize = canvasId
                        .getHardcodedSize(kind: createdNode.kind,
                                          nodeType: createdNode.nodeTypeEntity.patchNodeEntity?.userVisibleType) ?? CGSize(width: CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER,
                              height: CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER)

                    // Add horizontal gap only
                    size.width += horizontalPadding

                    // Position within this depth level only (no global accumulation)
                    let currentRow = nodeIndex
                    log("📍 Node \(createdNode.id): currentRow=\(currentRow), nodeIndex=\(nodeIndex) (depth \(depthLevel))")

                    // Add horizontal stagger for multiple nodes at same depth to avoid cramping
                    let horizontalStagger: CGFloat = CGFloat(nodeIndex) * 50.0

                    let cumulativeX = cumulativeXOffset[depthLevel] ?? 0
                    let baseX = viewPortCenter.x + centeringOffset + cumulativeX
                    let finalX = baseX + horizontalStagger

                    let newPosition = CGPoint(
                        x: finalX,
                        y: viewPortCenter.y + CGFloat(currentRow) * rowHeight + yOffset  // Apply collision avoidance offset
                    )
                    log("📐 \(createdNode.title): depth=\(depthLevel), viewport=\(viewPortCenter.x), centering=\(centeringOffset), cumulative=\(cumulativeX), stagger=\(horizontalStagger) → finalX=\(finalX)")

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

            // ENHANCED LOGGING: Provide comprehensive summary for this depth level
            let newNodesAtLevel = createdNodesAtThisLevel.filter { createdNodes.contains($0.id) }
            let preservedNodes = processedNodes.filter { positionRegistry.shouldPreserve($0.id) }
            let repositionedNodes = processedNodes.count - preservedNodes.count

            log("📊 TOPO-SUMMARY for depth \(depthLevel):")
            log("   Total nodes processed: \(processedNodes.count)")
            log("   New nodes: \(newNodesAtLevel.count)")
            log("   Preserved positions: \(preservedNodes.count)")
            log("   Repositioned: \(repositionedNodes)")

            if !newNodesAtLevel.isEmpty {
                let newNodeTitles = newNodesAtLevel.map { $0.title }.joined(separator: ", ")
                log("   New nodes added: \(newNodeTitles)")
            }

            if !conflictedPositions.isEmpty {
                log("   ⚠️ Position conflicts resolved: \(conflictedPositions.count)")
            }

            let finalPositionsAtLevel = processedNodes.compactMap { node -> String? in
                let positionStr = getPositionString(node)
                return "\(node.title):\(positionStr)"
            }.joined(separator: " | ")
            log("   Final positions: \(finalPositionsAtLevel)")

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
