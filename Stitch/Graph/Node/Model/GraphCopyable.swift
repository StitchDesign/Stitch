//
//  GraphCopyable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/15/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import StitchSchemaKit
import StitchViewKit

// TODO: Move and version this
typealias NodeEntities = [NodeEntity]

protocol GraphCopyable {
    @MainActor
    func createCopy(newId: NodeId,
                    mappableData: NodeIdMap,
                    copiedNodeIds: NodeIdSet) -> Self
}

extension Dictionary {
    func get(_ id: Self.Key?) -> Self.Value? {
        guard let id = id else {
            return nil
        }

        return self.get(id)
    }
}

extension NodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: NodeIdMap,
                    copiedNodeIds: NodeIdSet) -> NodeEntity {
        .init(id: newId, 
              nodeTypeEntity: self.nodeTypeEntity
            .createCopy(newId: newId,
                        mappableData: mappableData,
                        copiedNodeIds: copiedNodeIds),
              title: self.title)
    }
}

extension NodeTypeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId : NodeId],
                    copiedNodeIds: NodeIdSet) -> NodeTypeEntity {
        switch self {
        case .patch(let patchEntity):
            return .patch(patchEntity.createCopy(newId: newId,
                                                 mappableData: mappableData,
                                                 copiedNodeIds: copiedNodeIds))
        case .layer(let layerEntity):
            return .layer(layerEntity.createCopy(newId: newId,
                                                 mappableData: mappableData,
                                                 copiedNodeIds: copiedNodeIds))
            
        case .group(let canvasEntity):
            return .group(canvasEntity.createCopy(newId: newId,
                                                  mappableData: mappableData,
                                                  copiedNodeIds: copiedNodeIds))
            
        case .component(var component):
            // Only change canvas
            component.canvasEntity = component.canvasEntity.createCopy(newId: newId,
                                                                       mappableData: mappableData,
                                                                       copiedNodeIds: copiedNodeIds)
            return .component(component)
        }
    }
}

extension CanvasNodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId : NodeId],
                    copiedNodeIds: NodeIdSet) -> CanvasNodeEntity {
        let newGroupId = mappableData.get(self.parentGroupNodeId)

        return .init(position: self.position,
                     zIndex: self.zIndex,
                     parentGroupNodeId: newGroupId)
    }
}

extension PortValue: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: NodeIdMap,
                    copiedNodeIds: NodeIdSet) -> PortValue {
        if let interactionId = self.getInteractionId,
           let newInteractionId = mappableData.get(interactionId.asNodeId) {
            return PortValue.assignedLayer(newInteractionId.asLayerNodeId)
        }
        
        // Nothing changed so return self
        return self
    }
}

// TODO: if we copied both an interaction node and its assigned layer, the new interaction node should have the new layer's id in its first input: https://github.com/vpl-codesign/stitch/issues/5288
extension NodePortInputEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: NodeIdMap,
                    copiedNodeIds: NodeIdSet) -> NodePortInputEntity {
        let newInputId = NodeIOCoordinate(portType: self.id.portType,
                                          nodeId: newId)

        return .init(id: newInputId, 
                     portData: self.portData.createCopy(newId: newId,
                                                        mappableData: mappableData,
                                                        copiedNodeIds: copiedNodeIds))
    }
}

extension PatchNodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> PatchNodeEntity {
        let newInputs = self.inputs.map { input in
            input.createCopy(newId: newId,
                             mappableData: mappableData,
                             copiedNodeIds: copiedNodeIds)
        }
        
        return .init(id: newId,
                     patch: self.patch,
                     inputs: newInputs, 
                     canvasEntity: self.canvasEntity
            .createCopy(newId: newId,
                        mappableData: mappableData,
                        copiedNodeIds: copiedNodeIds),
                     userVisibleType: self.userVisibleType,
                     splitterNode: self.splitterNode?
            .createCopy(newId: newId,
                        mappableData: mappableData,
                        copiedNodeIds: copiedNodeIds),
                     mathExpression: self.mathExpression)
    }
}

extension SplitterNodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> SplitterNodeEntity {
        // We want duplicated splitters to have slightly offsetted time
        // otherwise groups will have ports constantly change order.
        // Small hack here for a single copied node to prevent likelihood of equal dates.
        let isSingleCopiedNode = copiedNodeIds.count == 1
        let newDate = isSingleCopiedNode ? Date.now : self.lastModifiedDate + 1
        
        return .init(id: newId,
                     lastModifiedDate: newDate,
                     type: self.type)
    }
}

extension LayerInputDataEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId : NodeId],
                    copiedNodeIds: NodeIdSet) -> LayerInputDataEntity {
        .init(inputPort: self.inputPort.createCopy(newId: newId,
                                                   mappableData: mappableData,
                                                   copiedNodeIds: copiedNodeIds),
              canvasItem: self.canvasItem?.createCopy(newId: newId,
                                                      mappableData: mappableData,
                                                      copiedNodeIds: copiedNodeIds))
    }
}

extension LayerInputEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId : NodeId],
                    copiedNodeIds: NodeIdSet) -> LayerInputEntity {
        .init(packedData: self.packedData.createCopy(newId: newId,
                                                     mappableData: mappableData,
                                                     copiedNodeIds: copiedNodeIds),
              unpackedData: self.unpackedData.map {
            $0.createCopy(newId: newId,
                          mappableData: mappableData,
                          copiedNodeIds: copiedNodeIds)
        })
    }
}

extension LayerNodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> LayerNodeEntity {
        var newSchema = LayerNodeEntity(nodeId: newId,
                                        layer: self.layer,
                                        hasSidebarVisibility: self.hasSidebarVisibility,
                                        layerGroupId: mappableData.get(self.layerGroupId))
        
        // Iterate through layer inputs
        self.layer.layerGraphNode.inputDefinitions.forEach {
            newSchema[keyPath: $0.schemaPortKeyPath] = self[keyPath: $0.schemaPortKeyPath]
                .createCopy(newId: newId,
                            mappableData: mappableData,
                            copiedNodeIds: copiedNodeIds)
        }
        
        return newSchema
    }
}

extension NodeConnectionType: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> NodeConnectionType {
        switch self {
        case .upstreamConnection(let upstreamOutputCoordinate):
            let willChangeUpstreamCoordinate = copiedNodeIds.contains(upstreamOutputCoordinate.nodeId)

            if willChangeUpstreamCoordinate,
               let newUpstreamNodeId = mappableData.get(upstreamOutputCoordinate.nodeId) {
                return .upstreamConnection(
                    .init(portType: upstreamOutputCoordinate.portType,
                                                    nodeId: newUpstreamNodeId)
                    )
            } else {
                // Do not change upstream ID if node was not copied--this retains edges for copied nodes
                // pasted in the same project
                return .upstreamConnection(upstreamOutputCoordinate)
            }
            
        case .values(let values):
            let changedValues = values.map {
                $0.createCopy(newId: newId,
                              mappableData: mappableData,
                              copiedNodeIds: copiedNodeIds)
            }
            
            return .values(changedValues)
        }
    }
}

extension NodeEntities {
    @MainActor
    func createCopy(mappableData: NodeIdMap,
                    copiedNodeIds: NodeIdSet) -> NodeEntities {
        self.compactMap { node in
            guard let newId = mappableData.get(node.id) else {
                fatalErrorIfDebug()
                return nil
            }

            let nodeCopy = node.createCopy(newId: newId,
                                           mappableData: mappableData,
                                           copiedNodeIds: copiedNodeIds)
            return nodeCopy
        }
    }
}

extension SidebarLayerList {
    func createCopy(mappableData: NodeIdMap) -> SidebarLayerList {
        self.compactMap { layerData in
            guard let newId = mappableData.get(layerData.id) else {
                fatalErrorIfDebug()
                return nil
            }

            return SidebarLayerData(
                id: newId,
                children: layerData.children?
                    .createCopy(mappableData: mappableData)
            )
        }
    }
}

typealias AsyncCallback = @Sendable () async -> Void
typealias AsyncCallbackList = [AsyncCallback]

struct StitchComponentCopiedResult<T: Sendable>: Sendable where T: StitchComponentable {
    var component: T
    let copiedSubdirectoryFiles: StitchDocumentDirectory
}

extension Array where Element == AsyncCallback {
    func processEffects() async {
        for effect in self {
            await effect()
        }
    }
}

// maps original ids -> copied ids
typealias NodeIdMap = [NodeId: NodeId]

extension GraphEntity {
    /// Creates fresh IDs for OrderedSidebarLayers, all data in NodeEntities etc.
    @MainActor
    func changeIds() -> (GraphEntity, NodeIdMap) {
        let copiedNodeIds = self.nodes.map { $0.id }.toSet

        // Create mapping dictionary from old NodeID's to new NodeID's
        let nodeIdMap: NodeIdMap = self.nodes.reduce(into: NodeIdMap()) { result, node in
            // Skip if we already have a node id
            guard !result.get(node.id).isDefined else {
                return
            }

            result.updateValue(.init(), forKey: node.id)
        }

        
        let copiedNodes: NodeEntities = self.nodes
            .createCopy(mappableData: nodeIdMap,
                        copiedNodeIds: copiedNodeIds)

        let copiedSidebarLayers = self.orderedSidebarLayers
            .createCopy(mappableData: nodeIdMap)
        
        if !self.commentBoxes.isEmpty {
            fatalErrorIfDebug("Comment boxes need to have IDs changed here!")
        }

        let graphEntity = GraphEntity(id: self.id,
                                      name: self.name,
                                      nodes: copiedNodes,
                                      orderedSidebarLayers: copiedSidebarLayers,
                                      commentBoxes: self.commentBoxes)
        
        return (graphEntity, nodeIdMap)
    }
}

extension NodeTypeEntity {
    /// Resets canvases in focused group to nil. Used for node copy/pasting.
    @MainActor
    mutating func resetGroupId(_ focusedGroupId: GroupNodeType?) {
        switch self {
        case .patch(var patchNode):
            patchNode.canvasEntity.resetGroupId(focusedGroupId)
            self = .patch(patchNode)
        case .group(var canvas):
            canvas.resetGroupId(focusedGroupId)
            self = .group(canvas)
        case .component(var component):
            component.canvasEntity.resetGroupId(focusedGroupId)
            self = .component(component)
        case .layer(var layerNode):
            // Reset groups for inputs
            layerNode.layer.layerGraphNode.inputDefinitions.forEach {
                var schema = layerNode[keyPath: $0.schemaPortKeyPath]
                switch schema.mode {
                case .packed:
                    schema.packedData.canvasItem?.resetGroupId(focusedGroupId)
                case .unpacked:
                    schema.unpackedData = schema.unpackedData.map { unpackedInput in
                        var unpackedInput = unpackedInput
                        unpackedInput.canvasItem?.resetGroupId(focusedGroupId)
                        return unpackedInput
                    }
                }
                
                layerNode[keyPath: $0.schemaPortKeyPath] = schema
            }
            
            // Reset groups for outputs
            layerNode.outputCanvasPorts = layerNode.outputCanvasPorts.map { data in
                var data = data
                data?.resetGroupId(focusedGroupId)
                return data
            }
            
            self = .layer(layerNode)
        }
    }
}

extension CanvasNodeEntity {
    /// Resets canvases in focused group to nil. Used for node copy/pasting.
    mutating func resetGroupId(_ focusedGroupId: GroupNodeType?) {
        let isTopLevel = self.parentGroupNodeId == focusedGroupId?.groupNodeId

        // Set top-level copied nodes to parent nil
        if isTopLevel {
            self.parentGroupNodeId = nil
        }
    }
}

/*
 Notes:
 - only patch nodes can be duplicated via the canvas
 - only layer nodes can be duplicated via the sidebar
 - we can NEVER duplicate both patch nodes AND layer nodes AT THE SAME TIME
 */
extension StitchDocumentViewModel {
    @MainActor func createNewStitchComponent(componentId: UUID,
                                             groupNodeFocused: GroupNodeType?,
                                             selectedNodeIds: NodeIdSet) -> StitchComponentCopiedResult<StitchComponent> {
        // Get path from root
        self.visibleGraph.createComponent(componentId: componentId,
                                          groupNodeFocused: groupNodeFocused,
                                          selectedNodeIds: selectedNodeIds) { graph in
            let newPath = GraphDocumentPath(docId: self.id,
                                            componentId: componentId,
                                            componentsPath: self.visibleGraph.saveLocation)
            return StitchComponent(saveLocation: .localComponent(newPath),
                                   graph: graph)
        }
    }
}

extension GraphState {
    /// Used for copy-and-paste scenarios.
    @MainActor
    func createCopiedComponent(groupNodeFocused: GroupNodeType?,
                               selectedNodeIds: NodeIdSet) -> StitchComponentCopiedResult<StitchClipboardContent> {
        self.createComponent(componentId: .init(),
                             groupNodeFocused: groupNodeFocused,
                             selectedNodeIds: selectedNodeIds) { graph in
            StitchClipboardContent(graph: graph)
        }
    }
    
    /// For clipboard, `groupNodeFocused` represents the focused group node of the graph.
    /// For components, it must be defined and represent the ID of the newly created group node.
    @MainActor
    func createComponent<Data>(componentId: UUID,
                               groupNodeFocused: GroupNodeType?,
                               selectedNodeIds: NodeIdSet,
                               createComponentable: @escaping (GraphEntity) -> Data) -> StitchComponentCopiedResult<Data> where Data: StitchComponentable {
        let selectedNodes = self.getSelectedNodeEntities(for: selectedNodeIds)
            .map { node in
                var node = node
                node.nodeTypeEntity.resetGroupId(groupNodeFocused)
                return node
            }
        
        let selectedSidebarLayers = self.layersSidebarViewModel
            .createdOrderedEncodedData()
            .getSubset(from: selectedNodes.map { $0.id }.toSet)
        
        let copiedComponentData: [StitchComponent] = selectedNodes
            .getComponentData(masterComponentsDict: self.components)
        
        let newGraph = GraphEntity(id: componentId,
                                   name: "My Component",
                                   nodes: selectedNodes,
                                   orderedSidebarLayers: selectedSidebarLayers,
                                   commentBoxes: [])

        let copiedComponent = createComponentable(newGraph)
        
        let portValuesList: [PortValues?] = selectedNodes
            .flatMap { nodeEntity in
                nodeEntity.encodedInputsValues
            }
        
        let portValues: PortValues = portValuesList
            .flatMap { $0 ?? [] }
            
        let mediaUrls: [URL] = portValues.compactMap { (value: PortValue) -> URL? in
                guard let media = value.asyncMedia,
                      let mediaKey = media.mediaKey,
                      let originalMediaUrl = self.getMediaUrl(forKey: mediaKey) else {
                    return nil
                }

                return originalMediaUrl
            }
        
        // Copy directory for selected components
        let componentUrls: [URL] = copiedComponentData.map { componentData in
            // Save location same for
            componentData.rootUrl
        }

        return .init(component: copiedComponent,
                     copiedSubdirectoryFiles: .init(importedMediaUrls: mediaUrls,
                                                    componentDirs: componentUrls))
    }
}

extension Array where Element: StitchNestedListElement {
    /// Returns a subset of layers in sidebar given some selected set.
    func getSubset(from ids: Set<Element.ID>) -> [Element] {
        self.flatMap { sidebarData in
            guard ids.contains(sidebarData.id) else {
                // Recursively check children
                return sidebarData.children?.getSubset(from: ids) ?? []
            }

            return [sidebarData]
        }
    }
}

extension Array where Element: StitchNestedListElementObservable {
    /// Returns a subset of layers in sidebar given some selected set.
    @MainActor func getSubset(from ids: Set<Element.ID>) -> [Element] {
        self.flatMap { sidebarData in
            guard ids.contains(sidebarData.id) else {
                // Recursively check children
                return sidebarData.children?.getSubset(from: ids) ?? []
            }

            return [sidebarData]
        }
    }
}

extension GraphState {
    /// Synchronous caller for node copying, used for Option + drag.
    @MainActor
    func copyAndPasteSelectedNodes(selectedNodeIds: NodeIdSet,
                                   isOptionDragInSidebar: Bool = false) {
        log("copyAndPasteSelectedNodes: selectedNodeIds: \(selectedNodeIds)")
        // Copy nodes if no drag started yet
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused,
                                   selectedNodeIds: selectedNodeIds)
        
        // creates new ids for nodes and sidebar layers; updates nodes' positions (staggering for duplication)
        let (newComponent, nodeIdMap) = Self.updateCopiedNodes(
            component: copiedComponentResult.component,
            destinationGraphInfo: nil)
                
        log("copyAndPasteSelectedNodes: self.orderedSidebarLayers: \(self.orderedSidebarLayers)")
        
        let copiedSidebarLayers = newComponent.orderedSidebarLayers
        log("copyAndPasteSelectedNodes: copiedSidebarLayers: \(copiedSidebarLayers)")
        
        // Update top-level nodes to match current focused group
        let newNodes: [NodeEntity] = Self.createNewNodes(
            from: newComponent,
            focusedGroupNode: self.graphUI.groupNodeFocused?.asNodeId)
        
        let graph = self.addComponentToGraph(newComponent: newComponent,
                                             newNodes: newNodes,
                                             nodeIdMap: nodeIdMap,
                                             isOptionDragInSidebar: isOptionDragInSidebar)

        self.updateSync(from: graph)
        
        self.updateGraphAfterPaste(newNodes: newNodes)
    }

    @MainActor
    func copyToClipboard(selectedNodeIds: NodeIdSet) {
        // Copy selected nodes
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused,
                                   selectedNodeIds: selectedNodeIds)

        Task { [weak self] in
            guard let store = self?.storeDelegate else { return }
            
            // Delete all existing items in clipboard
            try? await store.clipboardEncoder.removeContents()
            
            try? await store.clipboardEncoder.processGraphCopyAction(copiedComponentResult)
        }
    }
}

extension DocumentEncodable {
    func processGraphCopyAction(_ copiedComponentResult: StitchComponentCopiedResult<StitchClipboardContent>) async throws {
        // Create directories if it doesn't exist
        let rootUrl = copiedComponentResult.component.rootUrl
        let _ = try? StitchFileManager.createDirectories(at: rootUrl,
                                                         withIntermediate: true)
        
        try await self.encodeNewComponent(copiedComponentResult)
        
        let pasteboard = UIPasteboard.general
        pasteboard.url = rootUrl.appendingVersionedSchemaPath()
    }
    
    func encodeNewComponent<T>(_ result: StitchComponentCopiedResult<T>) async throws where T: StitchComponentable {
        result.component.createUnzippedFileWrapper()
        
        let _ = try T.encodeDocument(result.component)

        // Process imported media side effects
        await self.importComponentFiles(result.copiedSubdirectoryFiles)
    }
    
    @MainActor
    func importComponentFiles(_ files: StitchDocumentDirectory,
                              graphMutation: (@Sendable @MainActor () -> ())? = nil) async {
        guard !files.isEmpty else {
            return
        }
        
        let _ = await self.copyFiles(from: files)
    }
}
