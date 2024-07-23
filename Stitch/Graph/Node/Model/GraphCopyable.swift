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

struct StitchComponent: Codable {
    var id = UUID()
    //    let type: StitchComponentType
    var nodes: [NodeEntity]
    let orderedSidebarLayers: SidebarLayerList
    // TODO: comment boxes
}

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
        let newGroupId = mappableData.get(self.parentGroupNodeId)

        return .init(id: newId,
                     position: self.position,
                     zIndex: self.zIndex,
                     // Update this later
                     parentGroupNodeId: newGroupId,
                     patchNodeEntity: self.patchNodeEntity?
                        .createCopy(newId: newId,
                                    mappableData: mappableData,
                                    copiedNodeIds: copiedNodeIds),
                     layerNodeEntity: self.layerNodeEntity?
                        .createCopy(newId: newId,
                                    mappableData: mappableData,
                                    copiedNodeIds: copiedNodeIds),
                     isGroupNode: self.isGroupNode,
                     title: self.title,
                     inputs: self.inputs.map { input in
                        input.createCopy(newId: newId,
                                         mappableData: mappableData,
                                         copiedNodeIds: copiedNodeIds)
                     })
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
        let newValues = self.values.map { values in
            values.map {
                $0.createCopy(newId: newId,
                              mappableData: mappableData,
                              copiedNodeIds: copiedNodeIds)
            }
        }

        var newUpstreamOutputCoordinate: NodeIOCoordinate?
        let newInputId = NodeIOCoordinate(portType: self.id.portType,
                                          nodeId: newId)

        if let upstreamOutputCoordinate = self.upstreamOutputCoordinate {
            let willChangeUpstreamCoordinate = copiedNodeIds.contains(upstreamOutputCoordinate.nodeId)

            if willChangeUpstreamCoordinate,
               let newUpstreamNodeId = mappableData.get(upstreamOutputCoordinate.nodeId) {
                newUpstreamOutputCoordinate = .init(portType: upstreamOutputCoordinate.portType,
                                                    nodeId: newUpstreamNodeId)
            } else {
                // Do not change upstream ID if node was not copied--this retains edges for copied nodes
                // pasted in the same project
                newUpstreamOutputCoordinate = upstreamOutputCoordinate
            }
        }

        return .init(id: newInputId,
                     nodeKind: self.nodeKind,
                     userVisibleType: self.userVisibleType,
                     values: newValues,
                     upstreamOutputCoordinate: newUpstreamOutputCoordinate)
    }
}

extension PatchNodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> PatchNodeEntity {
        .init(id: newId,
              patch: self.patch,
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
        .init(id: newId,
              lastModifiedDate: self.lastModifiedDate,
              type: self.type)
    }
}

extension LayerNodeEntity: GraphCopyable {
    func createCopy(newId: NodeId,
                    mappableData: [NodeId: NodeId],
                    copiedNodeIds: NodeIdSet) -> LayerNodeEntity {
        var newSchema = LayerNodeEntity(nodeId: newId,
                                        layer: self.layer,
                                        positionPort: positionPort.createCopy(newId: newId,
                                                                              mappableData: mappableData,
                                                                              copiedNodeIds: copiedNodeIds),
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
        case .upstreamConnection(let coordinate):
            var coordinate = coordinate
            coordinate.nodeId = mappableData.get(coordinate.nodeId) ?? coordinate.nodeId
            return .upstreamConnection(coordinate)
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

extension GraphState {
    @MainActor
    func createCopiedComponent(groupNodeFocused: NodeId?) -> StitchComponentCopiedResult {
        let selectedNodeIds = self.selectedNodeIds
        let selectedNodes = self.getSelectedNodeEntities(for: selectedNodeIds)
            .map { node in
                var node = node
                let isTopLevel = node.parentGroupNodeId == groupNodeFocused

                // Set top-level copied nodes to parent nil
                if isTopLevel {
                    node.parentGroupNodeId = nil
                }

                return node
            }

        let selectedSidebarLayers = self.orderedSidebarLayers
            .getSubset(from: selectedNodeIds)

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
    func copyAndPasteSelectedNodes() {
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused?.asNodeId)
        self.insertNewComponent(copiedComponentResult)
    }

    @MainActor
    func copyToClipboard() {
        // Copy selected nodes
        let copiedComponentResult = self
            .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused?.asNodeId)

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
