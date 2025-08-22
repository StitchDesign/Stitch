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

struct AIPatchBuilderFunctionInputs: Codable {
    let swiftui_source_code: String
    let layer_data_list: String
}

struct AIPatchBuilderFunctionInputsSchema: Encodable {
    let swiftui_source_code = OpenAISchema(type: .string)
    
    // MARK: string because no nesting support in structured outputs
    let layer_data_list = OpenAISchema(type: .string)
}

extension StitchDocumentViewModel {
    /// Recursively creates new sidebar layer data from AI result after creating nodes.
    @MainActor
    func createLayerNodeFromAI(newLayer: CurrentAIGraphData.LayerData,
                               existingGraph: GraphState,
                               idMap: inout [String : UUID]) throws {
        let newId = idMap.get(newLayer.node_id) ?? UUID()
        
        // Validation: Check for ID conflicts with different layer types
        if let existingId = idMap.get(newLayer.node_id),
           let existingNode = existingGraph.nodes.get(existingId),
           let existingLayerType = existingNode.kind.getLayer {
            let newLayerType = try newLayer.node_name.value.convert(to: PatchOrLayer.self).layer
            if existingLayerType != newLayerType {
                log("⚠️ ID conflict detected: \(newLayer.node_id) already maps to \(existingLayerType) but new layer is \(newLayerType)")
                fatalErrorIfDebug("ID conflict: same node_id with different layer types")
                // In release mode, this should have been caught by fixDuplicateNodeIds
            }
        }
        
        idMap.updateValue(newId, forKey: newLayer.node_id)
        idMap.updateValue(newId, forKey: newId.description)
        let graph = self.visibleGraph
        
        let migratedNodeName = try newLayer.node_name.value.convert(to: PatchOrLayer.self)
        let existingLayerNode = existingGraph.nodes.get(newId)
        let needsNewNodeCreation = existingLayerNode?.kind.getLayer != migratedNodeName.layer
        
        log("  📝 Processing: \(newLayer.node_id) -> \(newId), LayerType: \(migratedNodeName.layer), needsNew: \(needsNewNodeCreation)")
        
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
            
            log("    ✅ Created node: \(newId), actualType: \(newLayerNode.kind.getLayer)")
        }
        
        if let children = newLayer.children {
            log("    👶 Processing \(children.count) children for \(newLayer.node_id)")
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

extension CurrentAIGraphData.GraphData {
    @MainActor
    func applyAIGraph(to document: StitchDocumentViewModel,
                      viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate],
                      requestType: StitchAIRequestBuilder_V0.StitchAIRequestType) async throws {
        switch requestType {
        case .userPrompt:
            // User prompt-based requests are always assumed to be edit requests, which completely replace existing graph data
            try await self.createAIGraph(document: document)
        }
        
        document.encodeProjectInBackground()
    }
    
    @MainActor
    func createAIGraph(document: StitchDocumentViewModel) async throws {
        guard let aiManager = document.aiManager else {
            return
        }
        
        let graph = document.visibleGraph
        let graphCenter = document.viewPortCenter
        let highestZIndex = document.visibleGraph.highestZIndex
        
        // Track node ID map to create new IDs, fixing ID reusage issue
        // Make sure currently used IDs are tracked so we don't create redundant nodes
        var idMap = graph.nodes.keys.reduce(into: [String : UUID]()) { result, nodeId in
            result.updateValue(nodeId, forKey: nodeId.description)
        }
        
        // Tracks all patch input coordinates we either make connections or custom vaues for, used for determining if extra rows need to be created
        let allModifiedPatchIds = self.patch_data.custom_patch_input_values.map(\.patch_input_coordinate) + self.patch_data.patch_connections.map(\.dest_port)
        let allModifiedPatchIdsSet = Set(allModifiedPatchIds)
//        assertInDebug(allModifiedPatchIdsSet.count == allModifiedPatchIds.count)
        
        let maxModifiedPortIndex: [String : Int] = allModifiedPatchIdsSet.reduce(into: .init()) { result, patchInputId in
            let nodeId = patchInputId.node_id
            let existingMaxCount = result.get(nodeId) ?? -1
            result.updateValue(max(patchInputId.port_index + 1, existingMaxCount),
                               forKey: nodeId)
        }
        
        // new js patches
        for newPatch in self.patch_data.javascript_patches {
            let newId = idMap.get(newPatch.node_id) ?? UUID()
            idMap.updateValue(newId, forKey: newPatch.node_id)
            idMap.updateValue(newId, forKey: newId.description)
            
            let newNode = graph.nodes.get(newId) ?? graph
                .createNode(graphTime: .zero,
                            newNodeId: newId,
                            highestZIndex: highestZIndex,
                            choice: .patch(.javascript),
                            center: graphCenter)
            
            graph.visibleNodesViewModel.nodes.updateValue(newNode, forKey: newId)
            
            // Initialize delegates for later helpers (like edges)
            newNode.initializeDelegate(graph: graph,
                                       document: document)
            
            if let patchNode = newNode.patchNode {
                // Get AI info
                let jsNodeRequest = AIJSNodeSettingsFromScritptRequest(existingScript: newPatch.sourceCode)
                
                let jsSettings = try await jsNodeRequest
                    .request(document: document,
                             aiManager: aiManager)
                
                patchNode.processNewJavascript(response: jsSettings,
                                               document: document)
                
                // Check here
                assertInDebug(patchNode.javaScriptNodeSettings != nil)
            }
        }
        
        // new native patches
        for newPatch in self.patch_data.native_patches {
            let oldId = newPatch.node_id
            let newId = idMap.get(oldId) ?? UUID()
            idMap.updateValue(newId, forKey: oldId)
            idMap.updateValue(newId, forKey: newId.description)
            
            let migratedNodeName = try newPatch.node_name.value.convert(to: PatchOrLayer.self)
            let existingPatchNode = graph.nodes.get(newId)
            let needsNewNodeCreation = existingPatchNode?.patch != migratedNodeName.patch
            let newNode: NodeViewModel
            
            if needsNewNodeCreation {
                newNode = graph.nodes.get(newId) ?? graph
                    .createNode(graphTime: .zero,
                                newNodeId: newId,
                                highestZIndex: highestZIndex,
                                choice: migratedNodeName,
                                center: graphCenter)
                
                graph.visibleNodesViewModel.nodes.updateValue(newNode, forKey: newId)
                
                // Initialize delegates for later helpers (like edges)
                newNode.initializeDelegate(graph: graph,
                                           document: document)
            }
        }
        
        // Set input values for new nodes
        for (oldId, newId) in idMap {
            guard let newNode = graph.nodes.get(newId) else {
                fatalErrorIfDebug()
                continue
            }
            
            // Set custom value type here
            if let customValueType = self.patch_data.native_patch_value_type_settings.first(where: { $0.node_id == oldId })?.value_type,
               let oldType = newNode.userVisibleType {
                let newType = try customValueType.value.migrate()
                let _ = document.graph.changeType(for: newNode,
                                                  oldType: oldType,
                                                  newType: newType,
                                                  activeIndex: document.activeIndex,
                                                  graphTime: document.graphStepState.graphTime)
            }
            
            // MARK: BEFORE creating edges/inputs, determine if new patch nodes need extra inputs
            if let patchNode = newNode.patchNodeViewModel {
                let supportsNewInputs = patchNode.patch.canChangeInputCounts
                if let maxModifiedInputIndex = maxModifiedPortIndex.get(oldId) {
                    let missingRowCount = maxModifiedInputIndex - patchNode.inputsObservers.count
                    
                    if missingRowCount > 0 {
                        guard supportsNewInputs else {
                            throw SwiftUISyntaxError.unexpectedPatchInputRowCount(patchNode.patch)
                        }
                        
                        for _ in (0..<missingRowCount) {
                            newNode.addInputObserver(graph: document.graph,
                                                     document: document)
                        }
                    }
                }                
            }
        }
        
        // Fix any duplicate node_ids in the layer hierarchy
        log("🔍 Checking for duplicate node IDs in layer_data_list...")
        let (fixedLayerDataList, duplicateIdMapping) = self.layer_data_list.fixDuplicateNodeIds()
        
        if !duplicateIdMapping.isEmpty {
            log("⚠️ Fixed \(duplicateIdMapping.count) duplicate node IDs:")
            for (oldId, newId) in duplicateIdMapping {
                log("  \(oldId) -> \(newId)")
            }
        }
        
        // create nested layer nodes in graph
        for newLayer in fixedLayerDataList {
            log("🔍 Creating layer node: \(newLayer.node_id), type: \(newLayer.node_name.value), children: \(newLayer.children?.count ?? 0)")
            // Recursive caller
            try document.createLayerNodeFromAI(newLayer: newLayer,
                                               existingGraph: graph,
                                               idMap: &idMap)
        }
        
        // Create nested sidebar layer data AFTER idMap gets updated from above layer logic
        log("🎯 Creating SidebarLayerData from LayerData...")
        let newSidebarData = try fixedLayerDataList.map { try $0.createSidebarLayerData(idMap: idMap) }
        
        // Debug: Check what's in the graph before detection
        log("📊 Graph nodes summary:")
        for (nodeId, node) in graph.nodes {
            if let layer = node.kind.getLayer {
                log("  Graph[\(nodeId)]: \(layer)")
            }
        }
        
        // Debug: Check for oval layers with children before updating sidebar
        let ovalLayersWithChildren = newSidebarData.detectOvalLayersWithChildren(graph: graph)
        if !ovalLayersWithChildren.isEmpty {
            log("⚠️ Detected oval layers with children:")
            for (layerId, childrenCount) in ovalLayersWithChildren {
                if let node = graph.getNode(layerId) {
                    log("  - Layer \(layerId): \(childrenCount) children, graphNodeType: \(node.kind.getLayer)")
                } else {
                    log("  - Layer \(layerId): \(childrenCount) children, graphNode: NOT FOUND")
                }
            }
            fatalErrorIfDebug("Found oval layers with children - this should not happen")
        }
        
        // Update sidebar view model data with new layer data
        graph.layersSidebarViewModel.update(from: newSidebarData)
        
        // new constants for patches
        for newInputValueSetting in self.patch_data.custom_patch_input_values {
            let inputCoordinate = try NodeIOCoordinate(
                from: newInputValueSetting.patch_input_coordinate,
                idMap: idMap)
            try document.updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                      valueType: newInputValueSetting.value_type.value,
                                                      data: newInputValueSetting.value,
                                                      idMap: &idMap)
        }
        
        // new state for layers
        try fixedLayerDataList.allNestedCustomInputValues { layerNodeId, newInputValueSetting in
            let inputCoordinate = try NodeIOCoordinate(
                from: .init(layer_id: layerNodeId,
                            input_port_type: newInputValueSetting.coordinate),
                idMap: idMap)
            
            switch newInputValueSetting.inputData {
            case .value(let value):
                try document
                    .updateCustomInputValueFromAI(inputCoordinate: inputCoordinate,
                                                  valueType: value.value_type.value,
                                                  data: value.value,
                                                  idMap: &idMap)

            case .stateRef(let varName):
                // Get upstream patch data from variable name
                guard let upstreamPatchCoordinate = viewStatePatchConnections
                    .get(varName),
                      let upstreamNodeId = idMap.get(upstreamPatchCoordinate.node_id) else {
//                    fatalErrorIfDebug()
                    return
                }
                
                let newEdgeData = PortEdgeData(from: .init(portId: upstreamPatchCoordinate.port_index,
                                                           nodeId: upstreamNodeId),
                                               to: inputCoordinate)
                
                // create canvas node
                guard let node = graph.getNode(upstreamNodeId),
                      let fromNodeLocation = node.nonLayerCanvasItem?.position,
                      let destinationNode = document.visibleGraph.getNode(inputCoordinate.nodeId),
                      let layerInputType = inputCoordinate.keyPath else {
                    throw SwiftUISyntaxError.layerEdgeDataFailure(varName)
                }

                var position = fromNodeLocation
                position.x += 200
                
                document.addCanvasLayerInput(node: destinationNode,
                                             layerInputType: layerInputType,
                                             draggedOutput: nil,
                                             canvasHeightOffset: nil,
                                             position: position)
                
                graph.addEdgeWithoutGraphRecalc(edge: newEdgeData)
            }
        }
        
        // new edges to downstream patches
        for newPatchEdge in self.patch_data.patch_connections {
            let inputPort = try NodeIOCoordinate(
                from: newPatchEdge.dest_port,
                idMap: idMap)
            let outputPort = try NodeIOCoordinate(
                from: newPatchEdge.src_port,
                idMap: idMap)
            let edge: PortEdgeData = PortEdgeData(
                from: outputPort,
                to: inputPort)
            
            let _ = document.visibleGraph.addEdgeWithoutGraphRecalc(edge: edge)
        }
        
        // Delete unused nodes
        let allNewIds = self.patch_data.javascript_patches.map(\.node_id) +
        self.patch_data.native_patches.map(\.node_id) +
        fixedLayerDataList.allFlattenedItems.map(\.node_id)
        
        let allNewMappedIds = allNewIds.compactMap { idMap.get($0) }
        let nodeIdsToDelete = Set(document.visibleGraph.nodes.keys).subtracting(allNewMappedIds)

        for nodeIdToDelete in nodeIdsToDelete {
            document.visibleGraph.deleteNode(id: nodeIdToDelete,
                                             document: document)
        }
        
        // Can't build the depth map from the `patch_data`,
        // since those UUIDs have not been remapped yet
        positionAIGeneratedNodesDuringApply(
            nodes: document.visibleGraph.visibleNodesViewModel,
            viewPortCenter: document.viewPortCenter,
            graph: document.visibleGraph)
        
        // Update topological data--needs to be forced here because of script building using this data
        
        // TODO: explore here?
        document.graph.updateGraphData(document)
        
        // Tests SwiftUI code creation to make sure this can work later
//        #if !RELEASE
//        do {
//            let _ = try document.graph.createSwiftUICode()
//        } catch {
//            throw error
////            fatalError(error.localizedDescription)
//        }
//        #endif
    }
}

extension Array where Element == CurrentAIGraphData.LayerData {
    /// Detects and fixes duplicate node_ids in the layer hierarchy.
    /// Returns new layer data with unique IDs and a mapping of old->new IDs.
    func fixDuplicateNodeIds() -> (fixedLayers: [CurrentAIGraphData.LayerData], idMapping: [String: String]) {
        var seenIds = Set<String>()
        var idMapping = [String: String]()
        
        func fixLayer(_ layer: CurrentAIGraphData.LayerData) -> CurrentAIGraphData.LayerData {
            let originalId = layer.node_id
            var fixedLayer = layer
            
            // Check if this ID has been seen before
            if seenIds.contains(originalId) {
                // Generate a new unique ID
                let newId = UUID().uuidString
                log("🔧 Fixed duplicate ID: \(originalId) -> \(newId)")
                fixedLayer.node_id = newId
                idMapping[originalId] = newId
            } else {
                seenIds.insert(originalId)
            }
            
            // Recursively fix children
            if let children = layer.children {
                fixedLayer.children = children.map { fixLayer($0) }
            }
            
            return fixedLayer
        }
        
        let fixedLayers = self.map { fixLayer($0) }
        return (fixedLayers: fixedLayers, idMapping: idMapping)
    }
}

extension Array where Element == SidebarLayerData {
    /// Recursively detects oval layers that incorrectly have children.
    /// Returns array of problematic layer IDs with their children count.
    
    @MainActor
    func detectOvalLayersWithChildren(graph: GraphState) -> [(layerId: UUID, childrenCount: Int)] {
        var results: [(layerId: UUID, childrenCount: Int)] = []
        
        func crawlLayer(_ layer: SidebarLayerData) {
            // Check if this layer is an oval with children
            if let layerNode = graph.getNode(layer.id),
               let layerKind = layerNode.kind.getLayer,
               layerKind == .oval,
               let children = layer.children,
               !children.isEmpty {
                results.append((layerId: layer.id, childrenCount: children.count))
            }
            
            // Recursively check all children
            layer.children?.forEach { childLayer in
                crawlLayer(childLayer)
            }
        }
        
        // Process all layers at the top level
        self.forEach { layer in
            crawlLayer(layer)
        }
        
        return results
    }
}

extension NodeIOCoordinate {
    init(from aiPatchCoordinate: CurrentAIGraphData.NodeIndexedCoordinate,
         idMap: [String : UUID]) throws {
        guard let newId = idMap.get(aiPatchCoordinate.node_id) else {
            log("updateCustomInputValueFromAI: idMap did not have aiPatchCoordinate.node_id \(aiPatchCoordinate.node_id), idMap: \(idMap)")
            throw AIPatchBuilderRequestError.nodeIdNotFound
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
