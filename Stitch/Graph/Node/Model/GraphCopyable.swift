//
//  GraphCopyable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/15/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UniformTypeIdentifiers

// TODO: Move and version this
typealias NodeEntities = [NodeEntity]

protocol GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
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
                    mappableData: [NodeId: NodeId],
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
                    mappableData: [NodeId: NodeId],
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
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> NodePortInputEntity {
        let newInputId = NodeIOCoordinate(portType: self.id.portType,
                                          nodeId: newId)

        return .init(id: newInputId, 
                     portData: self.portData.createCopy(newId: newId,
                                                        mappableData: mappableData,
                                                        copiedNodeIds: copiedNodeIds),
                     nodeKind: self.nodeKind,
                     userVisibleType: self.userVisibleType)
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
                                        layerGroupId: mappableData.get(self.layerGroupId),
                                        isExpandedInSidebar: self.isExpandedInSidebar)
        
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
    func createCopy(mappableData: [NodeId: NodeId],
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
    func createCopy(mappableData: [NodeId: NodeId]) -> SidebarLayerList {
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
typealias ComponentAsyncCallback = @Sendable (any DocumentEncodable) async -> Void

struct StitchComponentCopiedResult<T>: Sendable where T: StitchComponentable {
    let component: T
    let effects: [ComponentAsyncCallback]
}

extension Array where Element == AsyncCallback {
    func processEffects() async {
        for effect in self {
            await effect()
        }
    }
}

extension Array where Element == ComponentAsyncCallback {
    func processEffects(_ encoder: any DocumentEncodable) async {
        for effect in self {
            await effect(encoder)
        }
    }
}

extension StitchComponentable {
    /// Creates fresh IDs for all data in NodeEntities
    func changeIds() -> StitchClipboardContent {
        let copiedNodeIds = self.nodes.map { $0.id }.toSet

        // Create mapping dictionary from old NodeID's to new NodeID's
        let mappableData = self.nodes.reduce(into: [NodeId: NodeId]()) { result, node in
            // Skip if we already have a node id
            guard !result.get(node.id).isDefined else {
                return
            }

            result.updateValue(.init(), forKey: node.id)
        }

        let copiedNodes: NodeEntities = self.nodes
            .createCopy(mappableData: mappableData,
                        copiedNodeIds: copiedNodeIds)

        let copiedSidebarLayers = self.orderedSidebarLayers
            .createCopy(mappableData: mappableData)

        return .init(nodes: copiedNodes,
                     orderedSidebarLayers: copiedSidebarLayers)
    }
}

extension NodeTypeEntity {
    /// Resets canvases in focused group to nil. Used for node copy/pasting.
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
extension GraphState {
    @MainActor
    func createCopiedComponent(groupNodeFocused: GroupNodeType?,
                               selectedNodeIds: NodeIdSet) -> StitchComponentCopiedResult<StitchClipboardContent> {
        self.createComponent(groupNodeFocused: groupNodeFocused,
                             selectedNodeIds: selectedNodeIds) {
            StitchClipboardContent(nodes: $0, orderedSidebarLayers: $1)
        }
    }
    
    @MainActor func createNewStitchComponent(componentId: UUID,
                                             groupNodeFocused: GroupNodeType?,
                                             saveLocation: ComponentSaveLocation,
                                             selectedNodeIds: NodeIdSet) -> StitchComponentCopiedResult<StitchComponent> {
        self.createComponent(groupNodeFocused: groupNodeFocused,
                             selectedNodeIds: selectedNodeIds) {
            StitchComponent(graph: .init(id: componentId,
                                         name: "My Component",
                                         nodes: $0,
                                         orderedSidebarLayers: $1,
                                         commentBoxes: [],
                                         draftedComponents: []))
        }
    }
    
    /// For clipboard, `groupNodeFocused` represents the focused group node of the graph.
    /// For components, it must be defined and represent the ID of the newly created group node.
    @MainActor
    func createComponent<Data>(groupNodeFocused: GroupNodeType?,
                               selectedNodeIds: NodeIdSet,
                               createComponentable: @escaping (NodeEntities, SidebarLayerList) -> Data) -> StitchComponentCopiedResult<Data> where Data: StitchComponentable {
        let selectedNodes = self.getSelectedNodeEntities(for: selectedNodeIds)
            .map { node in
                var node = node
                node.nodeTypeEntity.resetGroupId(groupNodeFocused)
                return node
            }
        
        let selectedSidebarLayers = self.orderedSidebarLayers
            .getSubset(from: selectedNodes.map { $0.id }.toSet)

        let copiedComponent = createComponentable(selectedNodes, selectedSidebarLayers)
        
        let portValuesList: [PortValues?] = selectedNodes
            .flatMap { nodeEntity in
                nodeEntity.encodedInputsValues
            }
        
        let portValues: PortValues = portValuesList
            .flatMap { $0 ?? [] }
            
        let effects: [ComponentAsyncCallback] = portValues.compactMap { [weak self] (value: PortValue) -> ComponentAsyncCallback? in
                guard let graph = self,
                      let media = value._asyncMedia,
                      let mediaKey = media.mediaKey,
                      let originalMediaUrl = graph.getMediaUrl(forKey: mediaKey) else {
                    return nil
                }

                // Create imported media
                return { encoder in
                    let _ = await encoder.copyToMediaDirectory(originalURL: originalMediaUrl,
                                                               forRecentlyDeleted: false)
                }
            }

        return .init(component: copiedComponent, effects: effects)
    }
}

extension SidebarLayerList {
    /// Returns a subset of layers in sidebar given some selected set.
    func getSubset(from ids: NodeIdSet) -> SidebarLayerList {
        self.flatMap { sidebarData in
            guard ids.contains(sidebarData.id) else {
                // Recursively check children
                return sidebarData.children?.getSubset(from: ids) ?? []
            }

            return [sidebarData]
        }
    }
}


// TODO: move
protocol StitchComponentable: Sendable, StitchDocumentEncodable, Transferable {
    var nodes: [NodeEntity] { get set }
    var orderedSidebarLayers: SidebarLayerList { get set }
    static var fileType: UTType { get }
    var rootUrl: URL { get }
    var dataJsonUrl: URL { get }
}

//extension StitchComponent: StitchComponentable { }

struct StitchClipboardContent: StitchComponentable {
    static let fileType = UTType.stitchClipboard
    static let dataJsonName = StitchDocument.graphDataFileName
    
    var id = UUID()
    var nodes: [NodeEntity]
    var orderedSidebarLayers: SidebarLayerList
}

extension StitchClipboardContent: StitchDocumentEncodable {
    var rootUrl: URL {
        StitchFileManager.tempDir
            .appendingPathComponent("copied-data",
                                    conformingTo: Self.fileType)
    }
    
    var dataJsonUrl: URL {
        self.rootUrl
            .appendingPathComponent(StitchClipboardContent.dataJsonName,
                                    conformingTo: .json)
    }
    
    func getEncodingUrl(documentRootUrl: URL) -> URL {
        // Ignore param, always using temp directory
        self.rootUrl
    }
}

extension StitchComponentable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: self.fileType,
                           exporting: Self.exportComponent)
    }

    @Sendable
    static func exportComponent(_ component: Self) async -> SentTransferredFile {
        let rootUrl = component.rootUrl
        // Create directories if it doesn't exist
        let _ = try? await StitchFileManager.createDirectories(at: rootUrl,
                                                               withIntermediate: true)
        await component.encodeDocumentContents(folderUrl: rootUrl)

        let url = component.dataJsonUrl
        await Self.exportComponent(component, url: url)
        return SentTransferredFile(url)
    }

    @Sendable
    static func exportComponent(_ component: Self, url: URL) async {
        do {
            let encodedData = try getStitchEncoder().encode(component)
            try encodedData.write(to: url, options: .atomic)
        } catch {
            fatalErrorIfDebug("exportComponent error: \(error)")
        }
    }
}

extension GraphState {
    @MainActor
    func copyAndPasteSelectedNodes(selectedNodeIds: NodeIdSet) {
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused,
                                   selectedNodeIds: selectedNodeIds)
        self.insertNewComponent(copiedComponentResult)
    }

    @MainActor
    func copyToClipboard(selectedNodeIds: NodeIdSet) {
        // Copy selected nodes
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused,
                                   selectedNodeIds: selectedNodeIds)

        Task { [weak self] in
            await self?.documentEncoderDelegate?.processGraphCopyAction(copiedComponentResult)
        }
    }
}

extension DocumentEncodable {
    func processGraphCopyAction(_ copiedComponentResult: StitchComponentCopiedResult<StitchClipboardContent>) async {
        await self.encodeComponent(copiedComponentResult)
        
        let pasteboard = UIPasteboard.general
        pasteboard.url = copiedComponentResult.component.rootUrl
    }
    
    func encodeComponent<T>(_ result: StitchComponentCopiedResult<T>) async where T: StitchComponentable {
        let _ = await T.exportComponent(result.component)

        // Process imported media side effects
        await result.effects.processEffects(self)
    }
}
