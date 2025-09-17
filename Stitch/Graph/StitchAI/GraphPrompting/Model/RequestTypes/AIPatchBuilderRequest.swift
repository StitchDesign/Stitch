//
//  AIPatchBuilderRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

enum AIPatchBuilderRequestError: Error {
    case nodeIdNotFound
}

/// Matches nodes from old graph to new graph based on similarity
struct NodeSimilarityMatcher {
    let oldNodes: [NodeViewModel]
    let graph: GraphState

    /// Calculates similarity score between two nodes (0.0 to 1.0)
    @MainActor
    func calculateSimilarity(oldNode: NodeViewModel, newNodeType: PatchOrLayer, newInputValues: [CurrentAIGraphData.CustomPatchInputValue] = []) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. Exact type match (highest weight: 3 points)
        maxScore += 3.0
        if let oldPatch = oldNode.patch {
            if case .patch(let newPatch) = newNodeType, oldPatch == newPatch {
                score += 3.0
            }
        } else if let oldLayer = oldNode.kind.getLayer {
            if case .layer(let newLayer) = newNodeType, oldLayer == newLayer {
                score += 3.0
            }
        }

        // 2. Input values match (medium-high weight: 2.5 points)
        maxScore += 2.5
        var inputMatchScore = 0.0

        let oldInputs = oldNode.inputs
        if !oldInputs.isEmpty {
            var totalComparisons = 0
            var matchScore = 0.0

            for (index, oldInputList) in oldInputs.enumerated() {
                // Compare actual values in each input port
                for oldValue in oldInputList {
                    totalComparisons += 1
                    // TODO: When we have newInputValues available, we can directly compare:
                    // if newValue == oldValue { matchScore += 1.0 }
                    // For now, give partial credit for having values
                    matchScore += 0.5 // Half credit for having a value
                }
            }

            if totalComparisons > 0 {
                inputMatchScore = 2.5 * (matchScore / Double(totalComparisons))
            }
        }
        score += inputMatchScore

        // 3. Connection pattern match (medium weight: 2 points)
        maxScore += 2.0
        var connectionScore = 0.0

        // Count upstream connections (inputs with connections)
        let upstreamCount = oldNode.getAllInputsObservers().compactMap { input in
            (input as? InputNodeRowObserver)?.upstreamOutputCoordinate
        }.count

        // Count downstream connections (outputs that likely have connections)
        // Note: We can't directly check downstream from the node, but having outputs suggests connections
        let downstreamPotential = oldNode.getAllOutputsObservers().count

        // Score based on connection complexity
        if upstreamCount > 0 || downstreamPotential > 0 {
            // Give points for having similar connection patterns
            // This helps distinguish between isolated nodes and connected ones
            connectionScore = 2.0 * min(1.0, Double(upstreamCount + downstreamPotential) / 10.0)
        }
        score += connectionScore

        // 4. Node kind category match (low weight: 0.5 points)
        maxScore += 0.5
        if (oldNode.patch != nil && newNodeType.isPatch) ||
           (oldNode.kind.getLayer != nil && newNodeType.isLayer) {
            score += 0.5
        }

        return maxScore > 0 ? score / maxScore : 0.0
    }

    /// Finds the best matching existing node for a new node specification
    @MainActor
    func findBestMatch(for newNodeType: PatchOrLayer, newNodeId: String, idMap: [String: UUID]) -> NodeViewModel? {
        // First check if we already have this ID mapped
        if let existingId = idMap[newNodeId],
           let existingNode = graph.nodes[existingId] {
            // Check if the type is compatible
            let similarity = calculateSimilarity(oldNode: existingNode, newNodeType: newNodeType)
            if similarity > 0.7 { // High confidence threshold
                return existingNode
            }
        }

        // Otherwise, find best match among all old nodes
        var bestMatch: NodeViewModel?
        var bestScore = 0.0
        let threshold = 0.5 // Minimum similarity threshold

        for oldNode in oldNodes {
            let score = calculateSimilarity(oldNode: oldNode, newNodeType: newNodeType)
            if score > bestScore && score >= threshold {
                bestScore = score
                bestMatch = oldNode
            }
        }

        return bestMatch
    }
}

/// Matches nodes from old graph to new graph based on similarity, adapted for NodeEntity
struct NodeEntitySimilarityMatcher {
    let oldNodes: [UUID: NodeEntity]
    let oldNodeViewModels: [UUID: NodeViewModel]
    let document: StitchDocumentViewModel

    @MainActor
    func calculateSimilarity(oldNode: NodeEntity,
                            oldViewModel: NodeViewModel?,
                            newNodeType: PatchOrLayer) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. Exact type match (highest weight: 3 points)
        maxScore += 3.0
        switch oldNode.nodeTypeEntity {
        case .patch(let patchEntity):
            if case .patch(let newPatch) = newNodeType, patchEntity.patch == newPatch {
                score += 3.0
                Swift.print("    🎯 Patch type match: \\(patchEntity.patch) == \\(newPatch)")
            } else if case .patch(let newPatch) = newNodeType {
                Swift.print("    ❌ Patch type mismatch: \\(patchEntity.patch) != \\(newPatch)")
            }
        case .layer(let layerEntity):
            if case .layer(let newLayer) = newNodeType, layerEntity.layer == newLayer {
                score += 3.0
                Swift.print("    🎯 Layer type match: \\(layerEntity.layer) == \\(newLayer)")
            } else if case .layer(let newLayer) = newNodeType {
                Swift.print("    ❌ Layer type mismatch: \\(layerEntity.layer) != \\(newLayer)")
            }
        default:
            break
        }

        // 2. Input values match (medium-high weight: 2.5 points)
        maxScore += 2.5
        var inputMatchScore = 0.0

        if let vm = oldViewModel {
            let oldInputs = vm.inputs
            if !oldInputs.isEmpty {
                var totalComparisons = 0
                var matchScore = 0.0

                for (index, oldInputList) in oldInputs.enumerated() {
                    // Compare actual values in each input port
                    for oldValue in oldInputList {
                        totalComparisons += 1
                        // TODO: When we have newInputValues available, we can directly compare:
                        // if newValue == oldValue { matchScore += 1.0 }
                        // For now, give partial credit for having values
                        matchScore += 0.5 // Half credit for having a value
                    }
                }

                if totalComparisons > 0 {
                    inputMatchScore = 2.5 * (matchScore / Double(totalComparisons))
                }
                Swift.print("    🔢 Input analysis: \\(totalComparisons) values, partial score: \\(inputMatchScore)")
            }
        }
        score += inputMatchScore

        // 3. Connection pattern match (medium weight: 2 points)
        maxScore += 2.0
        var connectionScore = 0.0

        if let vm = oldViewModel {
            // Count upstream connections (inputs with connections)
            let upstreamCount = vm.getAllInputsObservers().compactMap { input in
                (input as? InputNodeRowObserver)?.upstreamOutputCoordinate
            }.count

            // Count downstream connections (outputs that likely have connections)
            let downstreamPotential = vm.getAllOutputsObservers().count

            // Score based on connection complexity
            if upstreamCount > 0 || downstreamPotential > 0 {
                connectionScore = 2.0 * min(1.0, Double(upstreamCount + downstreamPotential) / 10.0)
                Swift.print("    🔗 Connections: \\(upstreamCount) upstream, \\(downstreamPotential) downstream, score: \\(connectionScore)")
            }
        }
        score += connectionScore

        // 4. Node kind category match (low weight: 0.5 points)
        maxScore += 0.5
        let oldIsPatch = oldNode.nodeTypeEntity.patchNodeEntity != nil
        if (oldIsPatch && newNodeType.isPatch) || (!oldIsPatch && newNodeType.isLayer) {
            score += 0.5
        }

        let finalScore = maxScore > 0 ? score / maxScore : 0.0
        Swift.print("    📊 Similarity score: \\(score)/\\(maxScore) = \\(finalScore)")
        return finalScore
    }

    @MainActor
    func findBestMatch(for newNodeType: PatchOrLayer,
                      newNodeId: String,
                      idMap: [String: UUID]) -> (NodeEntity, NodeViewModel?)? {
        // First check if we already have this ID mapped
        if let existingId = idMap[newNodeId],
           let existingNode = oldNodes[existingId] {
            let vm = oldNodeViewModels[existingId]
            let similarity = calculateSimilarity(oldNode: existingNode,
                                                oldViewModel: vm,
                                                newNodeType: newNodeType)
            if similarity > 0.7 { // High confidence threshold
                return (existingNode, vm)
            }
        }

        // Find best match among all old nodes
        var bestMatch: (NodeEntity, NodeViewModel?)?
        var bestScore = 0.0
        let threshold = 0.5

        Swift.print("  🔍 Checking \\(oldNodes.count) existing nodes for matches:")
        for (nodeId, oldNode) in oldNodes {
            Swift.print("    Comparing with existing node: \\(nodeId)")
            let vm = oldNodeViewModels[nodeId]
            let score = calculateSimilarity(oldNode: oldNode,
                                           oldViewModel: vm,
                                           newNodeType: newNodeType)
            if score > bestScore && score >= threshold {
                bestScore = score
                bestMatch = (oldNode, vm)
                Swift.print("    ✅ New best match with score \\(score)")
            }
        }

        if let bestMatch = bestMatch {
            Swift.print("  🎯 Best match found with score: \\(bestScore)")
        } else {
            Swift.print("  ❌ No match found above threshold \\(threshold)")
        }

        return bestMatch
    }
}

struct AIPatchBuilderFunctionInputs: Codable {
    let swiftui_source_code: String
    let layer_data_list: String
}

struct AIPatchBuilderFunctionInputsSchema: Encodable {
    let swiftui_source_code = OpenAISchema(type: .string)
    
    // MARK: string because no nesting support in structured outputs
    let layer_data_list = OpenAISchema(type: .string)
}

extension Array where Element == AIGraphData_V0.LayerData {
    @MainActor
    func createLayerNodes(layerGroupId: UUID?,
                          nodesDict: inout [UUID: NodeEntity],
                          stateVarConnections: inout [String: NodeIOCoordinate]) {
        self.forEach { layerData in
            guard let layer = layerData.node_name.value.layer else {
                fatalErrorIfDebug()
                return
            }
            
            let layerNodeEntity = layer
                .createDefaultLayerNodeEntity(nodeId: UUID(layerData.node_id) ?? UUID(),
                                              layerGroupId: layerGroupId)
            
            let nodeEntity = NodeEntity(id: layerNodeEntity.id,
                                        nodeTypeEntity: .layer(layerNodeEntity),
                                        title: layerData.suggested_title ?? "")
            
            nodesDict.updateValue(nodeEntity,
                                  forKey: layerNodeEntity.id)

            layerData.custom_layer_input_values.forEach { portDerivation in
                let coordinate = portDerivation.coordinate
                
                portDerivation.inputData.forEach { inputData in
                    // Parse actions at this input, which may include patch data in the event of view events
                    nodesDict.updateWithEventData(inputData,
                                                  layerInputCoordinate: .init(portType: .keyPath(coordinate),
                                                                              nodeId: layerNodeEntity.id),
                                                  varName: nil,
                                                  stateVarConnections: &stateVarConnections)
                }
            }
            
            
            if let children = layerData.children {
                children
                    .createLayerNodes(layerGroupId: layerNodeEntity.id,
                                      nodesDict: &nodesDict,
                                      stateVarConnections: &stateVarConnections)
            }
        }
    }
}

//extension StitchDocumentViewModel {
//    /// Recursively creates new sidebar layer data from AI result after creating nodes.
//    @MainActor
//    func createLayerNodeFromAI(newLayer: CurrentAIGraphData.LayerData,
//                               existingGraph: GraphState,
//                               idMap: inout [String : UUID]) throws {
//        let newId = idMap.get(newLayer.node_id) ?? UUID(newLayer.node_id) ?? UUID()
//        idMap.updateValue(newId, forKey: newLayer.node_id)
//        idMap.updateValue(newId, forKey: newId.description)
//        let graph = self.visibleGraph
//        
//        let migratedNodeName = try newLayer.node_name.value.convert(to: PatchOrLayer.self)
//        let existingLayerNode = existingGraph.nodes.get(newId)
//        let needsNewNodeCreation = existingLayerNode?.kind.getLayer != migratedNodeName.layer
//        
//        if needsNewNodeCreation {
//            // Creates new layer node view model
//            let newLayerNode = graph
//                .createNode(graphTime: self.graphStepState.graphTime,
//                            newNodeId: newId,
//                            highestZIndex: graph.highestZIndex,
//                            choice: migratedNodeName,
//                            center: self.newCanvasItemInsertionLocation)
//            
//            graph.visibleNodesViewModel.nodes.updateValue(newLayerNode,
//                                                          forKey: newLayerNode.id)
//
//            // Initialize delegates for later helpers (like edges)
//            newLayerNode.initializeDelegate(graph: graph,
//                                            document: self)
//        }
//        
//        if let children = newLayer.children {
//            for child in children {
//                // Recursive call
//                try self.createLayerNodeFromAI(newLayer: child,
//                                               existingGraph: existingGraph,
//                                               idMap: &idMap)
//            }
//        }
//    }
//    
//    @MainActor
//    func updateCustomInputValueFromAI(inputCoordinate: NodeIOCoordinate,
//                                      valueType: AIGraphData_V0.NodeType,
//                                      data: (any Codable & Sendable),
//                                      idMap: inout [String : UUID]) throws {
//        guard let inputObserver = graph.getInputObserver(coordinate: inputCoordinate) else {
//            log("applyAction: could not apply setInput")
//            // fatalErrorIfDebug()
//            throw StitchAIStepHandlingError.actionValidationError("Could not retrieve input \(inputCoordinate)")
//        }
//        
//        let graph = self.visibleGraph
//        
//        let value = try AIGraphData_V0.PortValue.decodeFromAI(data: data,
//                                                       valueType: valueType,
//                                                       idMap: &idMap)
//        let migratedValue = try value.migrate()
//        
//        // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
//        graph.inputEditCommitted(input: inputObserver,
//                                 value: migratedValue,
//                                 activeIndex: self.activeIndex)
//    }
//}

extension SwiftSyntaxActionsResult {
    @MainActor
    mutating func applyAIGraph(to document: StitchDocumentViewModel,
                               viewStatePatchConnections: [String : NodeIOCoordinate]) async {
        // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
        self.createAIGraph(document: document)
        document.encodeProjectInBackground()
    }
    
    @MainActor
    mutating func createAIGraph(document: StitchDocumentViewModel) {
        var viewStatePatchConnections = self.graphData.viewStatePatchConnections

        // Store existing state for preservation
        let existingGraph = document.visibleGraph
        let existingNodeEntities = document.graph.createSchema().nodes.reduce(into: [UUID: NodeEntity]()) { result, node in
            result[node.id] = node
        }
        let existingNodeViewModels = existingGraph.nodes

        // Preserve sidebar and canvas selections
        let preservedSidebarSelection = existingGraph.layersSidebarViewModel.primary
        let preservedLastFocused = existingGraph.layersSidebarViewModel.lastFocused
        let preservedCanvasSelection = existingGraph.selection.selectedCanvasItems

        Swift.print("🔍 SIDEBAR SELECTION DEBUG:")
        Swift.print("  Preserved sidebar selection: \(preservedSidebarSelection)")
        Swift.print("  Preserved last focused: \(String(describing: preservedLastFocused))")
        let existingLayerNodes = existingNodeEntities.values.filter { node in
            if case .layer = node.nodeTypeEntity { return true }
            return false
        }.map(\.id)
        Swift.print("  Existing layer nodes: \(existingLayerNodes)")

        // Create similarity matcher
        let matcher = NodeEntitySimilarityMatcher(oldNodes: existingNodeEntities,
                                                  oldNodeViewModels: existingNodeViewModels,
                                                  document: document)

        // Track which old nodes have been matched
        var matchedOldNodeIds = Set<UUID>()
        var idMap = [String: UUID]()

        // Process patch nodes with similarity matching
        var nodesDict = [UUID: NodeEntity]()
        for patchNode in self.graphData.patchNodes {
            let nodeIdString = patchNode.id.description

            // Try to find a matching existing node
            if let patchType = patchNode.nodeTypeEntity.patchNodeEntity?.patch {
                let patchOrLayer = PatchOrLayer.patch(patchType)
                if let (matchedNode, _) = matcher.findBestMatch(for: patchOrLayer,
                                                               newNodeId: nodeIdString,
                                                               idMap: idMap) {
                    // Reuse the existing node's ID
                    let updatedNode = NodeEntity(id: matchedNode.id,
                                                nodeTypeEntity: patchNode.nodeTypeEntity,
                                                title: patchNode.title)
                    nodesDict[matchedNode.id] = updatedNode
                    idMap[nodeIdString] = matchedNode.id
                    idMap[matchedNode.id.description] = matchedNode.id
                    matchedOldNodeIds.insert(matchedNode.id)
                    continue
                }
            }

            // No match found, use new node as-is
            nodesDict[patchNode.id] = patchNode
            idMap[nodeIdString] = patchNode.id
            idMap[patchNode.id.description] = patchNode.id
        }

        // Process layer nodes with similarity matching
        func processLayerWithMatching(_ layerData: AIGraphData_V0.LayerData,
                                     layerGroupId: UUID?) {
            guard let layer = layerData.node_name.value.layer else {
                fatalErrorIfDebug()
                return
            }

            let layerIdString = layerData.node_id
            let layerOrPatch = PatchOrLayer.layer(layer)
            var finalNodeId = UUID(layerIdString) ?? UUID()

            // Try to find a matching existing node
            if let (matchedNode, _) = matcher.findBestMatch(for: layerOrPatch,
                                                           newNodeId: layerIdString,
                                                           idMap: idMap) {
                Swift.print("  ✅ Found layer match: \(layer) -> \(matchedNode.id)")
                finalNodeId = matchedNode.id
                matchedOldNodeIds.insert(matchedNode.id)
            } else {
                Swift.print("  ❌ No layer match found for: \(layer) (id: \(layerIdString))")
            }

            // Update idMap
            idMap[layerIdString] = finalNodeId
            idMap[finalNodeId.description] = finalNodeId

            // Create the layer node entity
            let layerNodeEntity = layer
                .createDefaultLayerNodeEntity(nodeId: finalNodeId,
                                            layerGroupId: layerGroupId)

            let nodeEntity = NodeEntity(id: layerNodeEntity.id,
                                       nodeTypeEntity: .layer(layerNodeEntity),
                                       title: layerData.suggested_title ?? "")

            nodesDict[finalNodeId] = nodeEntity

            // Process custom input values
            layerData.custom_layer_input_values.forEach { portDerivation in
                let coordinate = portDerivation.coordinate
                portDerivation.inputData.forEach { inputData in
                    nodesDict.updateWithEventData(inputData,
                                                 layerInputCoordinate: .init(portType: .keyPath(coordinate),
                                                                            nodeId: finalNodeId),
                                                 varName: nil,
                                                 stateVarConnections: &viewStatePatchConnections)
                }
            }

            // Process children recursively
            if let children = layerData.children {
                for child in children {
                    processLayerWithMatching(child, layerGroupId: layerNodeEntity.id)
                }
            }
        }

        // Process all layer nodes
        for layerData in self.graphData.layer_data_list {
            processLayerWithMatching(layerData, layerGroupId: nil)
        }

        // Preserve positions for matched nodes
        var finalNodes = Array(nodesDict.values)
        for i in 0..<finalNodes.count {
            let node = finalNodes[i]
            if matchedOldNodeIds.contains(node.id),
               let existingViewModel = existingNodeViewModels[node.id],
               let canvasItem = existingViewModel.nonLayerCanvasItem {
                // Preserve the position from the existing node
                // Only handle patch nodes for now (not layer canvas items)
                if var patchEntity = node.nodeTypeEntity.patchNodeEntity {
                    patchEntity.canvasEntity.position = canvasItem.position
                    patchEntity.canvasEntity.zIndex = canvasItem.zIndex
                    finalNodes[i] = NodeEntity(id: node.id,
                                              nodeTypeEntity: .patch(patchEntity),
                                              title: node.title)
                }
            }
        }

        // Start building final graph entity
        var graphEntity = document.graph.createSchema()
        graphEntity.nodes = finalNodes
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        let newSidebarData = self.graphData.layer_data_list.compactMap {
            $0.createSidebarLayerData()
        }
        
        graphEntity.orderedSidebarLayers = newSidebarData
        
        // Update sidebar view model data with new layer data
//        graph.layersSidebarViewModel.update(from: newSidebarData)
        
        // new state for layers
//        self.graphData.layer_data_list.allNestedCustomInputValues { layerNodeId, newInputValueSetting in
//            do {
//                let inputCoordinate = try NodeIOCoordinate(
//                    from: .init(layer_id: layerNodeId,
//                                input_port_type: newInputValueSetting.coordinate),
//                    idMap: idMap)
//                
//                for valueResult in newInputValueSetting.inputData {
//                    switch valueResult {
//                    case .portData(let connectionType):
//                        switch connectionType {
//                        case .values(let values):
//                            try document
//                                .updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
//                                                              valueType: value.value_type.value,
//                                                              data: value.value,
//                                                              idMap: &idMap)
//                            
//                        case .stateRef(let varName):
//                            // Get upstream patch data from variable name
//                            guard let upstreamPatchCoordinate = self.graphData.viewStatePatchConnections
//                                .get(varName) else {
//                                //                    fatalErrorIfDebug()
//                                return
//                            }
//                            
//                            let newEdgeData = PortEdgeData(from: .init(portId: upstreamPatchCoordinate.portId!,
//                                                                       nodeId: upstreamPatchCoordinate.nodeId),
//                                                           to: inputCoordinate)
//                            
//                            // create canvas node
//                            guard let node = graph.getNode(upstreamPatchCoordinate.nodeId),
//                                  let fromNodeLocation = node.nonLayerCanvasItem?.position,
//                                  let destinationNode = document.visibleGraph.getNode(inputCoordinate.nodeId),
//                                  let layerInputType = inputCoordinate.keyPath else {
//                                throw SwiftUISyntaxError.layerEdgeDataFailure(varName)
//                            }
//                            
//                            var position = fromNodeLocation
//                            position.x += 200
//                            
//                            document.addCanvasLayerInput(node: destinationNode,
//                                                         layerInputType: layerInputType,
//                                                         draggedOutput: nil,
//                                                         canvasHeightOffset: nil,
//                                                         position: position)
//                            
//                            graph.addEdgeWithoutGraphRecalc(edge: newEdgeData)
//                        }
//                        
//                    case .stateRefInViewEvent(let memberAccessData):
//                        // TODO: come back here
//                        fatalErrorIfDebug()
//                    }
//                }
//                
//            } catch let error as SwiftUISyntaxError {
//                caughtErrors.append(error)
//            } catch {
//                fatalErrorIfDebug(error.localizedDescription)
//            }
//        }
        
        // new edges to downstream patches
//        for newPatchEdge in self.graphData.patch_data.patch_connections {
//            do {
//                let inputPort = try NodeIOCoordinate(
//                    from: newPatchEdge.dest_port,
//                    idMap: idMap)
//                let outputPort = try NodeIOCoordinate(
//                    from: newPatchEdge.src_port,
//                    idMap: idMap)
//                let edge: PortEdgeData = PortEdgeData(
//                    from: outputPort,
//                    to: inputPort)
//                
//                let _ = document.visibleGraph.addEdgeWithoutGraphRecalc(edge: edge)
//            } catch let error as SwiftUISyntaxError {
//                caughtErrors.append(error)
//            } catch {
//                fatalErrorIfDebug(error.localizedDescription)
//            }
//        }
        
        // Delete only truly unmatched nodes
        let allNewNodeIds = Set(nodesDict.keys)
        let nodeIdsToDelete = Set(existingNodeEntities.keys).subtracting(allNewNodeIds)

        for nodeIdToDelete in nodeIdsToDelete {
            document.visibleGraph.deleteNode(id: nodeIdToDelete,
                                           document: document)
        }
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        let repositionedNodes = graphEntity.nodes.positionAIGeneratedNodesDuringApply(
            viewPortCenter: document.viewPortCenter,
            graph: document.visibleGraph)
        graphEntity.nodes = repositionedNodes
        
        // Make group Id map current context
        graphEntity.nodes = graphEntity.nodes.map { nodeEntity in
            var nodeEntity = nodeEntity
            nodeEntity.canvasEntityMutator { canvasEntity in
                var canvasEntity = canvasEntity
                canvasEntity.parentGroupNodeId = document.groupNodeFocused?.groupNodeId
                return canvasEntity
            }
            return nodeEntity
        }
        
        // Update topological data--needs to be forced here because of script building using this data
        document.graph.update(from: graphEntity)
        document.graph.updateGraphData(document)

        // Restore selections after graph update
        Swift.print("🔍 SELECTION RESTORATION DEBUG:")
        Swift.print("  Matched old node IDs: \(matchedOldNodeIds)")
        Swift.print("  Preserved sidebar selection: \(preservedSidebarSelection)")

        // Filter the preserved sidebar selections to only include matched nodes
        let restoredSidebarSelection = preservedSidebarSelection.filter { sidebarItemId in
            matchedOldNodeIds.contains(sidebarItemId)
        }
        Swift.print("  Restored sidebar selection: \(restoredSidebarSelection)")

        if !restoredSidebarSelection.isEmpty {
            document.visibleGraph.layersSidebarViewModel.primary = restoredSidebarSelection
            Swift.print("  ✅ Restored sidebar selection: \(restoredSidebarSelection)")
        } else {
            Swift.print("  ❌ No sidebar selection to restore")
        }

        // Restore last focused if it was matched
        if let preservedFocus = preservedLastFocused,
           matchedOldNodeIds.contains(preservedFocus) {
            document.visibleGraph.layersSidebarViewModel.lastFocused = preservedFocus
            Swift.print("  ✅ Restored last focused: \(preservedFocus)")
        } else {
            Swift.print("  ❌ No last focused to restore")
        }

        if !preservedCanvasSelection.isEmpty {
            var restoredSelection = CanvasItemIdSet()
            for oldId in preservedCanvasSelection {
                let nodeId = oldId.nodeId
                if matchedOldNodeIds.contains(nodeId) {
                    restoredSelection.insert(.node(nodeId))
                }
            }
            if !restoredSelection.isEmpty {
                document.visibleGraph.selection.selectedCanvasItems = restoredSelection
            }
        }

        // Report errors
        caughtErrors.displayErrors(document: document)
    }
}

extension Array where Element == SwiftUISyntaxError {
    @MainActor
    func displayErrors(document: StitchDocumentViewModel) {
 
#if STITCH_AI_TESTING || DEBUG || DEV_DEBUG
        // In debug builds, show all errors (including silent ones) for development
        if !self.isEmpty {
            let caughtErrorsString = self.reduce(into: "") { stringBuilder, error in
                stringBuilder += "\n\(error)"
            }
            
            document.storeDelegate?.alertState.stitchFileError = .unknownError("Warnings for the following unknown concepts:\(caughtErrorsString)")
        }
#else
        // Filter out silent errors - only show errors that should interrupt the user
        let nonSilentErrors = self.filter { !$0.shouldFailSilently }
        
        // In production builds, only show non-silent errors to users
        if !nonSilentErrors.isEmpty {
            let nonSilentErrorsString = nonSilentErrors.reduce(into: "") { stringBuilder, error in
                stringBuilder += "\n\(error)"
            }
            
            document.storeDelegate?.alertState.stitchFileError = .unknownError("Warnings for the following unknown concepts:\(nonSilentErrorsString)")
        }
#endif
    }
}

extension NodeIOCoordinate {
    init(from aiPatchCoordinate: CurrentAIGraphData.NodeIndexedCoordinate,
         idMap: [String : UUID]) throws {
        guard let newId = idMap.get(aiPatchCoordinate.node_id) else {
            log("updateCustomInputValueFromAI: idMap did not have aiPatchCoordinate.node_id \(aiPatchCoordinate.node_id), idMap: \(idMap)")
            throw SwiftUISyntaxError.viewNodeNotFound
        }
        
        self.init(portId: aiPatchCoordinate.port_index,
                  nodeId: newId)
    }
    
    init(from aiLayerCoordinate: CurrentAIGraphData.LayerInputCoordinate,
         idMap: [String : UUID]) throws {
        guard let newId = idMap.get(aiLayerCoordinate.layer_id) else {
            fatalErrorIfDevDebug("updateCustomInputValueFromAI: idMap did not have aiLayerCoordinate.layer_id \(aiLayerCoordinate.layer_id), idMap: \(idMap)")
            throw AIPatchBuilderRequestError.nodeIdNotFound
        }
        
        let portType = AIGraphData_V0.NodeIOPortType
            .keyPath(.init(layerInput: aiLayerCoordinate.input_port_type.layerInput,
                           portType: aiLayerCoordinate.input_port_type.portType ))
        
        let migratedPortType = try portType.convert(to: NodeIOPortType.self)
        
        self.init(portType: migratedPortType,
                  nodeId: newId)
    }
}
