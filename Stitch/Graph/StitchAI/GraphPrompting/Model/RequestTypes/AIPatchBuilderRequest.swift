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
struct NodeEntitySimilarityMatcher {
    let oldNodes: [NodeEntity]

    /// Calculates similarity score between two nodes (0.0 to 1.0)
    func calculateSimilarity(oldNode: NodeEntity, newNodeType: PatchOrLayer) -> Double {
        log("calculateSimilarity: oldNodes.map(.id): \(oldNodes.map(\.id))")
        var score = 0.0
        var maxScore = 0.0

        // 1. Exact type match (highest weight: 3 points)
        maxScore += 3.0
        switch oldNode.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            if case .patch(let newPatch) = newNodeType, patchNodeEntity.patch == newPatch {
                log("calculateSimilarity: had matching patch: \(newPatch)")
                score += 3.0
            }
        case .layer(let layerNodeEntity):
            if case .layer(let newLayer) = newNodeType, layerNodeEntity.layer == newLayer {
                log("calculateSimilarity: had matching layer: \(newLayer)")
                score += 3.0
            }
        case .group:
            // TODO: Handle group node similarity
            break
        case .component:
            // TODO: Handle component node similarity
            break
        }

        // 2. Input values match (medium-high weight: 2.5 points)
        maxScore += 2.5
        var inputMatchScore = 0.0

        let oldInputValues = extractInputValues(from: oldNode)
        log("calculateSimilarity: oldInputValues: \(oldInputValues)")
        if !oldInputValues.isEmpty {
            var totalComparisons = 0
            var matchScore = 0.0

            for oldValueList in oldInputValues {
                for _ in oldValueList {
                    totalComparisons += 1
                    // TODO: When we have newInputValues available, we can directly compare values
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

        let (upstreamCount, downstreamPotential) = extractConnectionCounts(from: oldNode)

        // Score based on connection complexity
        if upstreamCount > 0 || downstreamPotential > 0 {
            // Give points for having similar connection patterns
            // This helps distinguish between isolated nodes and connected ones
            connectionScore = 2.0 * min(1.0, Double(upstreamCount + downstreamPotential) / 10.0)
        }
        score += connectionScore

        // 4. Node kind category match (low weight: 0.5 points)
        maxScore += 0.5
        let oldIsPatch = oldNode.nodeTypeEntity.patchNodeEntity != nil
        let oldIsLayer = oldNode.nodeTypeEntity.layerNodeEntity != nil

        if (oldIsPatch && newNodeType.isPatch) ||
           (oldIsLayer && newNodeType.isLayer) {
            score += 0.5
        }

        let finalScore = maxScore > 0 ? score / maxScore : 0.0
        log("calculateSimilarity: maxScore: \(maxScore)")
        log("calculateSimilarity: score: \(score)")
        log("calculateSimilarity: finalScore: \(finalScore)")
        return finalScore
    }

    /// Represents a match between an old node and new node with similarity score
    struct NodeMatch {
        let oldNode: NodeEntity
        let newNodeType: PatchOrLayer
        let newNodeId: UUID
        let similarity: Double
    }

    /// Performs one-to-one matching between old nodes and new nodes
    /// Returns matches above threshold, ensuring each old node is matched to at most one new node
    func findOptimalMatches(for newNodes: [(UUID, PatchOrLayer)]) -> [NodeMatch] {
        log("findOptimalMatches: for \(newNodes.count) new nodes")

        // Step 1: Create similarity matrix - calculate all possible matches
        var candidateMatches: [NodeMatch] = []
        let threshold = 0.5

        for (newNodeId, newNodeType) in newNodes {
            for oldNode in oldNodes {
                let similarity = calculateSimilarity(oldNode: oldNode, newNodeType: newNodeType)
                if similarity >= threshold {
                    candidateMatches.append(NodeMatch(
                        oldNode: oldNode,
                        newNodeType: newNodeType,
                        newNodeId: newNodeId,
                        similarity: similarity
                    ))
                }
            }
        }

        log("findOptimalMatches: found \(candidateMatches.count) candidate matches above threshold")

        // Step 2: Sort by similarity score (highest first) for greedy assignment
        candidateMatches.sort { $0.similarity > $1.similarity }

        // Step 3: Greedy one-to-one assignment
        var finalMatches: [NodeMatch] = []
        var usedOldNodeIds = Set<UUID>()
        var usedNewNodeIds = Set<UUID>()

        for candidate in candidateMatches {
            // Skip if either node is already matched
            if usedOldNodeIds.contains(candidate.oldNode.id) ||
               usedNewNodeIds.contains(candidate.newNodeId) {
                continue
            }

            // Accept this match and mark both nodes as used
            finalMatches.append(candidate)
            usedOldNodeIds.insert(candidate.oldNode.id)
            usedNewNodeIds.insert(candidate.newNodeId)

            log("findOptimalMatches: accepted match - old: \(candidate.oldNode.id) (\(candidate.oldNode.kind)) -> new: \(candidate.newNodeId) (\(candidate.newNodeType)), similarity: \(candidate.similarity)")
        }

        log("findOptimalMatches: final \(finalMatches.count) one-to-one matches")
        return finalMatches
    }

    /// Extracts input values from a NodeEntity
    private func extractInputValues(from node: NodeEntity) -> [[PortValue]] {
        switch node.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            return patchNodeEntity.inputs.compactMap { inputEntity in
                switch inputEntity.portData {
                case .values(let values):
                    log("extractInputValues: patch: for node \(node.id) \(node.kind), had input values: \(values)")
                    return values
                case .upstreamConnection:
                    log("extractInputValues: patch: for node \(node.id) \(node.kind), had an upstream connection and thus no input values")
                    return [] // Connected inputs don't have direct values
                }
            }
        case .layer(let layerNodeEntity):
            // Extract values from the main layer input ports
            var allValues: [[PortValue]] = []

            // Sample key ports for similarity analysis
            // TODO: Should we check more layer inputs down the road?
            let keyPorts = [
                layerNodeEntity.positionPort,
                layerNodeEntity.sizePort,
                layerNodeEntity.colorPort,
                layerNodeEntity.opacityPort,
                layerNodeEntity.rotationZPort
            ]

            for port in keyPorts {
                switch port.packedData.inputPort {
                case .values(let values):
                    allValues.append(values)
                case .upstreamConnection:
                    allValues.append([]) // Connected ports don't have direct values
                }

                // Also check unpacked data for loop connections
                for unpackedData in port.unpackedData {
                    switch unpackedData.inputPort {
                    case .values(let values):
                        allValues.append(values)
                    case .upstreamConnection:
                        allValues.append([])
                    }
                }
            }

            log("extractInputValues: layer: for node \(node.id) \(node.kind), had input values: allValues: \(allValues)")
            return allValues
        case .group:
            // TODO: Handle group node input extraction
            return []
        case .component:
            // TODO: Handle component node input extraction
            return []
        }
    }

    /// Extracts connection counts from a NodeEntity
    private func extractConnectionCounts(from node: NodeEntity) -> (upstream: Int, downstream: Int) {
        switch node.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            let upstreamCount = patchNodeEntity.inputs.reduce(0) { count, inputEntity in
                switch inputEntity.portData {
                case .upstreamConnection(let x):
                    log("extractConnectionCounts: patch: for node \(node.id) \(node.kind) and input \(inputEntity.id), had an upstream connection: \(x)")
                    return count + 1
                case .values:
                    log("extractConnectionCounts: patch: for node \(node.id) \(node.kind) and input \(inputEntity.id) had values")
                    return count
                }
            }
            // For downstream, we estimate based on patch type's typical output count
            // This is less precise than runtime analysis but gives a useful signal
            let downstreamPotential = 1 // Most patches have at least one output
            return (upstreamCount, downstreamPotential)
        case .layer(let layerNodeEntity):
            // Count upstream connections from layer input ports
            let keyPorts = [
                layerNodeEntity.positionPort,
                layerNodeEntity.sizePort,
                layerNodeEntity.colorPort,
                layerNodeEntity.opacityPort,
                layerNodeEntity.rotationZPort
            ]

            var upstreamCount = 0
            for port in keyPorts {
                // Check packed data
                if case .upstreamConnection = port.packedData.inputPort {
                    upstreamCount += 1
                }

                // Check unpacked data
                for unpackedData in port.unpackedData {
                    if case .upstreamConnection = unpackedData.inputPort {
                        upstreamCount += 1
                    }
                }
            }

            // Layers typically have one visual output
            return (upstreamCount, 1)
        case .group:
            // TODO: Handle group node connections
            return (0, 0)
        case .component:
            // TODO: Handle component node connections
            return (0, 0)
        }
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

extension StitchDocumentViewModel {
    /// Recursively creates new sidebar layer data from AI result after creating nodes.
    @MainActor
    func createLayerNodeFromAI(newLayer: CurrentAIGraphData.LayerData,
                               existingGraph: GraphState,
                               idMap: inout [String : UUID]) throws {
        let newId = idMap.get(newLayer.node_id) ?? UUID(newLayer.node_id) ?? UUID()
        idMap.updateValue(newId, forKey: newLayer.node_id)
        idMap.updateValue(newId, forKey: newId.description)
        let graph = self.visibleGraph
        
        let migratedNodeName = try newLayer.node_name.value.convert(to: PatchOrLayer.self)
        let existingLayerNode = existingGraph.nodes.get(newId)
        let needsNewNodeCreation = existingLayerNode?.kind.getLayer != migratedNodeName.layer
        
        if needsNewNodeCreation {
            // Creates new layer node view model
            let newLayerNode = graph
                .createNode(graphTime: self.graphStepState.graphTime,
                            newNodeId: newId,
                            highestZIndex: graph.highestZIndex,
                            choice: migratedNodeName,
                            center: self.newCanvasItemInsertionLocation)
            
            graph.visibleNodesViewModel.nodes.updateValue(newLayerNode,
                                                          forKey: newLayerNode.id)

            // Initialize delegates for later helpers (like edges)
            newLayerNode.initializeDelegate(graph: graph,
                                            document: self)
        }
        
        if let children = newLayer.children {
            for child in children {
                // Recursive call
                try self.createLayerNodeFromAI(newLayer: child,
                                               existingGraph: existingGraph,
                                               idMap: &idMap)
            }
        }
    }
    
    @MainActor
    func updateCustomInputValueFromAI(inputCoordinate: NodeIOCoordinate,
                                      valueType: AIGraphData_V0.NodeType,
                                      data: (any Codable & Sendable),
                                      idMap: inout [String : UUID]) throws {
        guard let inputObserver = graph.getInputObserver(coordinate: inputCoordinate) else {
            log("applyAction: could not apply setInput")
            // fatalErrorIfDebug()
            throw StitchAIStepHandlingError.actionValidationError("Could not retrieve input \(inputCoordinate)")
        }
        
        let graph = self.visibleGraph
        
        let value = try AIGraphData_V0.PortValue.decodeFromAI(data: data,
                                                       valueType: valueType,
                                                       idMap: &idMap)
        let migratedValue = try value.migrate()
        
        // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
        graph.inputEditCommitted(input: inputObserver,
                                 value: migratedValue,
                                 activeIndex: self.activeIndex)
    }
}

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
        // STEP 1: Capture existing state for similarity matching
        let existingGraph = document.graph.createSchema()
        let matcher = NodeEntitySimilarityMatcher(oldNodes: existingGraph.nodes)
        let previousSidebarSelection = document.graph.layersSidebarViewModel.primary
        var matchedNodeIds = Set<UUID>()

        var viewStatePatchConnections = self.graphData.viewStatePatchConnections
        
        // STEP 2: Apply similarity matching to patch nodes using one-to-one batch matching
        // We keep the new AI nodes but preserve positions from matched existing nodes

        // Prepare new patch nodes for batch matching
        let newPatchNodeData: [(UUID, PatchOrLayer)] = self.graphData.patchNodes.compactMap { currentPatch in
            if case .patch(let patchNodeEntity) = currentPatch.nodeTypeEntity {
                return (currentPatch.id, PatchOrLayer.patch(patchNodeEntity.patch))
            }
            return nil
        }

        // Perform optimal one-to-one matching
        let optimalMatches = matcher.findOptimalMatches(for: newPatchNodeData)
        Swift.print("Found \(optimalMatches.count) optimal matches for \(newPatchNodeData.count) new patch nodes")

        // Process the matches to build position mappings and selection mappings
        var nodePositionMappings: [UUID: CGPoint] = [:]  // new node ID -> old position
        var newNodesForSelectedOldNodes = Set<UUID>()  // new node IDs that should be selected

        for match in optimalMatches {
            // Only accept matches with high similarity scores
            if match.similarity > 0.5 {
                // Store the position mapping: new node should use old node's position
                if case .patch(let matchedPatchEntity) = match.oldNode.nodeTypeEntity {
                    nodePositionMappings[match.newNodeId] = matchedPatchEntity.canvasEntity.position
                    matchedNodeIds.insert(match.newNodeId)  // Track the NEW node ID

                    // If the old node was selected, mark the new node for selection
                    if previousSidebarSelection.contains(match.oldNode.id) {
                        newNodesForSelectedOldNodes.insert(match.newNodeId)
                    }

                    Swift.print("Matched new patch node \(match.newNodeId) (\(match.newNodeType)) with existing \(match.oldNode.id) (\(match.oldNode.kind)), similarity \(match.similarity)")
                }
            }
        }

        // Apply preserved positions to matched patch nodes
        var updatedPatchNodes = self.graphData.patchNodes
        for i in 0..<updatedPatchNodes.count {
            let nodeId = updatedPatchNodes[i].id
            if let preservedPosition = nodePositionMappings[nodeId],
               case .patch(var patchNodeEntity) = updatedPatchNodes[i].nodeTypeEntity {
                patchNodeEntity.canvasEntity.position = preservedPosition
                updatedPatchNodes[i].nodeTypeEntity = .patch(patchNodeEntity)
                Swift.print("Applied preserved position \(preservedPosition) to node \(nodeId)")
            }
        }

        // STEP 2.5: Apply similarity matching to layer nodes using one-to-one batch matching
        // Extract new layer data for matching before creating them
        let newLayerNodeData: [(UUID, PatchOrLayer)] = self.graphData.layer_data_list.flatMap { layerData -> [(UUID, PatchOrLayer)] in
            // Recursive function to extract all layer data including nested children
            func extractLayerData(from data: AIGraphData_V0.LayerData) -> [(UUID, PatchOrLayer)] {
                var results: [(UUID, PatchOrLayer)] = []

                // Add current layer
                if let layer = data.node_name.value.layer {
                    let layerId = UUID(data.node_id) ?? UUID()
                    results.append((layerId, PatchOrLayer.layer(layer)))
                }

                // Recursively add children
                if let children = data.children {
                    for child in children {
                        results.append(contentsOf: extractLayerData(from: child))
                    }
                }

                return results
            }

            return extractLayerData(from: layerData)
        }

        // Perform optimal one-to-one matching for layers
        let optimalLayerMatches = matcher.findOptimalMatches(for: newLayerNodeData)
        Swift.print("Found \(optimalLayerMatches.count) optimal layer matches for \(newLayerNodeData.count) new layer nodes")

        // Process layer matches to build position mappings and selection mappings
        var layerPositionMappings: [UUID: CGPoint] = [:]  // new layer ID -> old position
        var layerSidebarSelections = Set<UUID>()  // new layer IDs that should be selected
        var layerCanvasItemPositions: [String: CGPoint] = [:]  // "nodeId:port:mode" -> position

        for match in optimalLayerMatches {
            // Only accept matches with reasonable similarity scores
            if match.similarity > 0.5 {
                // Store the position mapping: new layer should use old layer's position
                if case .layer(let matchedLayerEntity) = match.oldNode.nodeTypeEntity {
                    Swift.print("📍 Capturing canvas positions for matched layer \(match.oldNode.id) -> \(match.newNodeId)")

                    // Iterate through all layer inputs to find canvas items
                    for inputDefinition in matchedLayerEntity.layer.layerGraphNode.inputDefinitions {
                        let portData = matchedLayerEntity[keyPath: inputDefinition.schemaPortKeyPath]

                        // Check packed canvas items
                        if let canvasItem = portData.packedData.canvasItem {
                            let key = "\(match.newNodeId):\(inputDefinition):packed"
                            layerCanvasItemPositions[key] = canvasItem.position
                            Swift.print("  ✅ Captured packed canvas for port \(inputDefinition): position \(canvasItem.position)")
                        }

                        // Check unpacked canvas items
                        for (index, unpackedData) in portData.unpackedData.enumerated() {
                            if let canvasItem = unpackedData.canvasItem {
                                let key = "\(match.newNodeId):\(inputDefinition):unpacked-\(index)"
                                layerCanvasItemPositions[key] = canvasItem.position
                                Swift.print("  ✅ Captured unpacked[\(index)] canvas for port \(inputDefinition): position \(canvasItem.position)")
                            }
                        }
                    }

                    matchedNodeIds.insert(match.newNodeId)  // Track the NEW layer ID for position skipping

                    let capturedCount = layerCanvasItemPositions.filter { $0.key.hasPrefix(match.newNodeId.uuidString) }.count
                    Swift.print("📍 Total preserved positions for layer: \(capturedCount)")

                    // If the old layer was selected, mark the new layer for selection
                    if previousSidebarSelection.contains(match.oldNode.id) {
                        layerSidebarSelections.insert(match.newNodeId)
                    }

                    Swift.print("Matched new layer node \(match.newNodeId) (\(match.newNodeType)) with existing \(match.oldNode.id) (\(match.oldNode.kind)), similarity \(match.similarity)")
                }
            }
        }

        // Add layer selections to the overall selection set
        newNodesForSelectedOldNodes.formUnion(layerSidebarSelections)

        // Build ID mapping for sidebar creation: AI node_id -> matched UUID
        var layerIdMapping: [String: UUID] = [:]

        // Helper function to recursively find AI node_id for a given UUID
        func findLayerNodeId(in layerDataList: [AIGraphData_V0.LayerData], targetUUID: UUID, callback: (String) -> Void) {
            for layerData in layerDataList {
                if UUID(layerData.node_id) == targetUUID {
                    callback(layerData.node_id)
                    return
                }
                if let children = layerData.children {
                    findLayerNodeId(in: children, targetUUID: targetUUID, callback: callback)
                }
            }
        }

        for match in optimalLayerMatches {
            if match.similarity > 0.5 {
                // Find the AI node_id string that corresponds to this matched UUID
                findLayerNodeId(in: self.graphData.layer_data_list, targetUUID: match.newNodeId) { nodeId in
                    layerIdMapping[nodeId] = match.newNodeId
                }
            }
        }

        // Sync patch graph nodes in document before parsing layers, which may need data from there
        var graphEntity = document.graph.createSchema()
        graphEntity.nodes = updatedPatchNodes

        var nodesDict = graphEntity.nodes.reduce(into: [UUID: NodeEntity]()) { result, nodeEntity in
            result.updateValue(nodeEntity, forKey: nodeEntity.id)
        }

        // create nested layer nodes in graph
        self.graphData.layer_data_list
            .createLayerNodes(layerGroupId: nil,
                              nodesDict: &nodesDict,
                              stateVarConnections: &viewStatePatchConnections)
        
        graphEntity.nodes = Array(nodesDict.values)
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        // Pass the layer ID mapping to preserve matched layer IDs
        let newSidebarData = self.graphData.layer_data_list.compactMap {
            $0.createSidebarLayerData(idMapping: layerIdMapping)
        }
        
        graphEntity.orderedSidebarLayers = newSidebarData
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        let repositionedNodes = graphEntity.nodes.positionAIGeneratedNodesDuringApply(
            viewPortCenter: document.viewPortCenter,
            graph: document.visibleGraph,
            matchedNodeIds: matchedNodeIds,
            layerCanvasItemPositions: layerCanvasItemPositions)
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

        // STEP 3: Restore sidebar selections for matched nodes
        document.graph.layersSidebarViewModel.primary = newNodesForSelectedOldNodes
        Swift.print("Restored sidebar selection for \(newNodesForSelectedOldNodes.count) matched nodes")

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
