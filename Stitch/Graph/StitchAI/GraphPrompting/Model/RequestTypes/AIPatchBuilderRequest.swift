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
        var score = 0.0
        var maxScore = 0.0

        // 1. Exact type match (highest weight: 3 points)
        maxScore += 3.0
        switch oldNode.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            if case .patch(let newPatch) = newNodeType, patchNodeEntity.patch == newPatch {
                score += 3.0
            }
        case .layer(let layerNodeEntity):
            if case .layer(let newLayer) = newNodeType, layerNodeEntity.layer == newLayer {
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

        return maxScore > 0 ? score / maxScore : 0.0
    }

    /// Finds the best matching existing node for a new node specification
    func findBestMatch(for newNodeType: PatchOrLayer) -> NodeEntity? {
        var bestMatch: NodeEntity?
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

    /// Extracts input values from a NodeEntity
    private func extractInputValues(from node: NodeEntity) -> [[PortValue]] {
        switch node.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            return patchNodeEntity.inputs.compactMap { inputEntity in
                switch inputEntity.portData {
                case .values(let values):
                    return values
                case .upstreamConnection:
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
                case .upstreamConnection:
                    return count + 1
                case .values:
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
//        guard let aiManager = document.aiManager else {
//            return
//        }
        
//        let graph = document.visibleGraph
//        let graphCenter = document.viewPortCenter
//        let highestZIndex = document.visibleGraph.highestZIndex
        var viewStatePatchConnections = self.graphData.viewStatePatchConnections
        
        // Sync patch graph nodes in document before parsing layers, which may need data from there
        var graphEntity = document.graph.createSchema()
        graphEntity.nodes = self.graphData.patchNodes
        
        // Update topological data--needs to be forced here because of script building using this data
//        document.graph.update(from: graphEntity)
//        document.graph.updateGraphData(document)
        
        // Track node ID map to create new IDs, fixing ID reusage issue
        // Make sure currently used IDs are tracked so we don't create redundant nodes
//        var idMap = graphEntity.nodes.reduce(into: [String : UUID]()) { result, node in
//            result.updateValue(node.id, forKey: node.id.description)
//        }
        
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
        
        // Delete unused nodes
//        let allNewIds = self.graphData.patch_data.javascript_patches.map(\.node_id) +
//        self.graphData.patch_data.native_patches.map(\.node_id) +
//        self.graphData.layer_data_list.allFlattenedItems.map(\.node_id)
//        
//        let allNewMappedIds = allNewIds.compactMap { idMap.get($0) }
//        let nodeIdsToDelete = Set(document.visibleGraph.nodes.keys).subtracting(allNewMappedIds)
//
//        for nodeIdToDelete in nodeIdsToDelete {
//            document.visibleGraph.deleteNode(id: nodeIdToDelete,
//                                             document: document)
//        }
        
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
