//
//  GraphCopyable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/15/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

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

struct StitchComponentCopiedResult: Sendable {
    let component: StitchComponent
    let effects: AsyncCallbackList
}

extension Array where Element == AsyncCallback {
    func processEffects() async {
        for effect in self {
            await effect()
        }
    }
}

extension StitchComponent {
    /// Creates fresh IDs for all data in NodeEntities
    func changeIds() -> StitchComponent {
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
    mutating func resetGroupId(_ focusedGroupId: NodeId?) {
        switch self {
        case .patch(var patchNode):
            patchNode.canvasEntity.resetGroupId(focusedGroupId)
            self = .patch(patchNode)
        case .group(var canvas):
            canvas.resetGroupId(focusedGroupId)
            self = .group(canvas)
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
    mutating func resetGroupId(_ focusedGroupId: NodeId?) {
        let isTopLevel = self.parentGroupNodeId == focusedGroupId

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
    func createCopiedComponent(groupNodeFocused: NodeId?,
                               selectedNodeIds: NodeIdSet) -> StitchComponentCopiedResult {
        let selectedNodes = self.getSelectedNodeEntities(for: selectedNodeIds)
            .map { node in
                var node = node
                node.nodeTypeEntity.resetGroupId(groupNodeFocused)
                return node
            }
        
        let selectedSidebarLayers = self.orderedSidebarLayers
            .getSubset(from: selectedNodes.map { $0.id }.toSet)

        let copiedComponent = StitchComponent(nodes: selectedNodes,
                                              orderedSidebarLayers: selectedSidebarLayers)

        let newImportedFilesDirectory = copiedComponent.rootUrl.appendingStitchMediaPath()
        
        let portValuesList: [PortValues?] = selectedNodes
            .flatMap { nodeEntity in
                nodeEntity.encodedInputsValues
            }
        
        let portValues: PortValues = portValuesList
            .flatMap { $0 ?? [] }
            
        let effects: [AsyncCallback] = portValues.compactMap { (value: PortValue) -> AsyncCallback? in
                guard let media = value._asyncMedia,
                      let mediaKey = media.mediaKey,
                      let originalMediaUrl = self.getMediaUrl(forKey: mediaKey) else {
                    return nil
                }

                // Create imported media
                return {
                    let _ = await StitchFileManager.copyToMediaDirectory(originalURL: originalMediaUrl,
                                                                         importedFilesURL: newImportedFilesDirectory)
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

extension StitchComponent: MediaDocumentEncodable {
    var rootUrl: URL {
        // TODO: adjust for permanently stored components
        StitchFileManager.tempDir
            .appendingPathComponent(self.id.uuidString,
                                    conformingTo: .stitchComponent)
    }

    static let dataJsonName = "data"
    var dataJsonUrl: URL {
        self.rootUrl.appendingDataJsonPath()
    }
}

extension StitchComponent: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .stitchComponent,
                           exporting: Self.exportComponent,
                           importing: Self.importComponent)
    }

    @Sendable
    static func exportComponent(_ component: StitchComponent) async -> SentTransferredFile {
        await component.encodeDocumentContents()

        let url = component.dataJsonUrl
        await StitchComponent.exportComponent(component, url: url)
        return SentTransferredFile(url)
    }

    @Sendable
    static func exportComponent(_ component: StitchComponent, url: URL) async {
        do {
            let encodedData = try getStitchEncoder().encode(component)
            try encodedData.write(to: url, options: .atomic)
        } catch {
            log("exportComponent error: \(error)")
            #if DEBUG
            fatalError()
            #endif
        }
    }

    @Sendable
    static func importComponent(_ received: ReceivedTransferredFile) async -> StitchComponent {
        fatalError()
        //        do {
        //            guard let doc = try await Self.importDocument(from: received.file,
        //                                                          isImport: true) else {
        //                //                #if DEBUG
        //                //                fatalError()
        //                //                #endif
        //                DispatchQueue.main.async {
        //                    dispatchStitch(.displayError(.unsupportedProject))
        //                }
        //                return StitchDocument()
        //            }
        //
        //            return doc
        //        } catch {
        //            #if DEBUG
        //            fatalError()
        //            #endif
        //            return StitchDocument()
        //        }
    }
}

extension GraphState {
    @MainActor
    func copyAndPasteSelectedNodes(selectedNodeIds: NodeIdSet) {
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused?.asNodeId, 
                                   selectedNodeIds: selectedNodeIds)
        self.insertNewComponent(copiedComponentResult)
    }

    @MainActor
    func copyToClipboard(selectedNodeIds: NodeIdSet) {
        // Copy selected nodes
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused?.asNodeId,
                                   selectedNodeIds: selectedNodeIds)

        Task { [weak self] in
            await self?.documentEncoder.processGraphCopyAction(copiedComponentResult)
        }
    }
}

extension DocumentEncoder {
    func processGraphCopyAction(_ copiedComponentResult: StitchComponentCopiedResult) async {
        let pasteboard = UIPasteboard.general
        
        let _ = await StitchComponent.exportComponent(copiedComponentResult.component)

        // Process imported media side effects
        await copiedComponentResult.effects.processEffects()

        pasteboard.url = copiedComponentResult.component.rootUrl
    }
}
