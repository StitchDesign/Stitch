//
//  NodeDuplicationActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchViewKit

struct CopyPasteGraphDestinationInfo: Equatable {
    let destinationGraphOffset: CGPoint
    let destinationGraphFrame: CGRect
    let destinationGraphScale: CGFloat
    let destinationGraphTraversalLevel: NodeId?
}

/// Adjust the position of pasted nodes, so that they are pasted in viewport.
@MainActor
func adjustPastedNodesPositions(pastedNodes: [NodeEntity],
                                destinationGraphOffset: CGPoint,
                                destinationGraphFrame: CGRect,
                                destinationGraphScale: CGFloat,
                                destinationGraphTraversalLevel: NodeId?) -> [NodeEntity] {

    let isAtThisTraversalLevel = { (canvasEntity: CanvasNodeEntity) -> Bool in
        canvasEntity.parentGroupNodeId == destinationGraphTraversalLevel
    }
    
    // Note: We only want to look at number of pasted canvas items present at destination graph's current traversal level.
    // So e.g. if pasting 2 GroupNodes and each GroupNode had 10 children, the canvasItemCount should be 2, not 20 or 22.
    let canvasItemCount = pastedNodes.reduce(0) { partialResult, nodeEntity in
        partialResult + nodeEntity.canvasEntities.filter(isAtThisTraversalLevel).count
    }
    
    let averageX = zeroCompatibleDivision(
        numerator: pastedNodes.reduce(0.0) { partialResult, nodeSchema in
            partialResult + nodeSchema.canvasEntities.filter(isAtThisTraversalLevel).reduce(0.0) { $0 + $1.position.x }
        },
        denominator: CGFloat(canvasItemCount))

    let averageY = zeroCompatibleDivision(
        numerator: pastedNodes.reduce(0.0) { partialResult, nodeSchema in
            partialResult + nodeSchema.canvasEntities.filter(isAtThisTraversalLevel).reduce(0.0) { $0 + $1.position.y }
        },
        denominator: CGFloat(canvasItemCount))
    
    
    return pastedNodes.reduce(into: [NodeEntity]()) { acc, node in
        var node = node

        node = node.canvasEntityMap { canvasEntity in
            
            // Do not modify position of pasted canvas items that are not at the destination graph's current traversal level
            guard isAtThisTraversalLevel(canvasEntity) else {
                return canvasEntity
            }
            
            var canvasEntity = canvasEntity
            
            canvasEntity.position.x -= averageX
            canvasEntity.position.y -= averageY
            
            // Factor out graph offset of paste-destination projects
            // SEE `StitchDocumentViewModel.viewPortCenter`
            let descaledLocalPosition = CGPoint(
                x: destinationGraphOffset.x / destinationGraphScale,
                y: destinationGraphOffset.y / destinationGraphScale
            )
            canvasEntity.position.x += descaledLocalPosition.x
            canvasEntity.position.y += descaledLocalPosition.y
            
            // Add 1/2 width and height to account for node position 0,0 = top left vs. graph postion 0,0 = center
            canvasEntity.position.x += destinationGraphFrame.width/2 * 1/destinationGraphScale
            canvasEntity.position.y += destinationGraphFrame.height/2 * 1/destinationGraphScale
            
            return canvasEntity
        }

        acc.append(node)
    }
}

struct DuplicateShortcutKeyPressed: StitchDocumentEvent {
    
    // Duplicates BOTH nodes AND comments
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        state.duplicateShortcutKeyPressed()
    }
}

extension SidebarLayerData {
    
    // Function to insert a list of new data structures after a specified `afterID`, returning a modified copy
       func insertingAfterId(_ newDataList: [SidebarLayerData], afterId: UUID) -> SidebarLayerData {
           // If there are no children, return the current structure as-is
           guard let children = children else {
               return self
           }
           
           var modifiedChildren = [SidebarLayerData]()
           
           for child in children {
               // If the current child's id matches afterID, insert all items from newDataList right after it
               if child.id == afterId {
                   modifiedChildren.append(child)
                   modifiedChildren.append(contentsOf: newDataList)
               } else {
                   // Otherwise, continue recursively in the child's children
                   modifiedChildren.append(child.insertingAfterId(newDataList, afterId: afterId))
               }
           }
           
           // Return a new SidebarLayerData instance with the modified children
           return SidebarLayerData(id: id, children: modifiedChildren)
       }

}

// Wrapper function to handle the insertion at the top level, returning a modified array
func insertAfterId(data: [SidebarLayerData], newDataList: [SidebarLayerData], afterId: UUID) -> [SidebarLayerData] {
    var modifiedData = [SidebarLayerData]()
    
    for item in data {
        // If the top-level item's id matches afterID, insert all items from newDataList after it
        if item.id == afterId {
            modifiedData.append(item)
            modifiedData.append(contentsOf: newDataList)
        } else {
            // Otherwise, apply insertion in the item's children recursively
            modifiedData.append(item.insertingAfterId(newDataList, afterId: afterId))
        }
    }
    
    return modifiedData
}


// returns nil when original layer id not found
func attemptToInsertBeforeId(originalLayers: [SidebarLayerData],
                             newLayers: [SidebarLayerData],
                             originalLayerId: UUID) -> [SidebarLayerData]? {
    
    var modifiedLayers = originalLayers
    
    // If this level has the original item, then just prepend here
    if let indexOfOriginalLayer = originalLayers.firstIndex(where: { $0.id == originalLayerId }) {
        // `insert at` = prepend
        modifiedLayers.insert(contentsOf: newLayers, at: indexOfOriginalLayer)
        return modifiedLayers
    }
    
    // Else, recur on each item's child-list.
    // The first item to have the original layer id, we prepend the new layers into, and then return.
    else {
        for x in modifiedLayers.enumerated() {
            let originalLayer = x.element
            let index = x.offset
            
            if let children = originalLayer.children {
                if let modifiedChildren = attemptToInsertBeforeId(
                    originalLayers: children,
                    newLayers: newLayers,
                    originalLayerId: originalLayerId) {
                    
                    var originalLayer = originalLayer
                    originalLayer.children = modifiedChildren
                    modifiedLayers[index] = originalLayer
                    return modifiedLayers
                }
            }
        }
    }
    
    // Could not find original layer id anywhere
    return nil
}



extension StitchDocumentViewModel {
    @MainActor
    func duplicateShortcutKeyPressed() {
        guard !self.llmRecording.isRecording else {
            log("Duplication disabled during LLM Recording")
            return
        }
        
        let activelySelectedLayers = self.visibleGraph.layersSidebarViewModel.isSidebarFocused
        
        if activelySelectedLayers {
            self.visibleGraph.sidebarSelectedItemsDuplicated(document: self)
            self.visibleGraph.encodeProjectInBackground()
        } else {
            let copiedComponentResult = self.visibleGraph.createCopiedComponent(
                groupNodeFocused: self.groupNodeFocused,
                selectedNodeIds: self.visibleGraph.selectedCanvasItems.compactMap(\.nodeCase).toSet)
                
            self.visibleGraph
                .insertNewComponent(copiedComponentResult,
                                    isCopyPaste: false,
                                    encoder: self.visibleGraph.documentEncoderDelegate,
                                    document: self)
            
            self.visibleGraph.encodeProjectInBackground()
        }
    }
}

extension GraphState {
    /// Inserts new component in state and processes media effects
    @MainActor
    func insertNewComponent<T>(_ copiedComponentResult: StitchComponentCopiedResult<T>,
                               isCopyPaste: Bool,
                               encoder: (any DocumentEncodable)?,
                               document: StitchDocumentViewModel) where T: StitchComponentable {
        
        self.insertNewComponent(component: copiedComponentResult.component,
                                encoder: encoder,
                                copiedFiles: copiedComponentResult.copiedSubdirectoryFiles,
                                isCopyPaste: isCopyPaste,
                                document: document)
    }

    @MainActor
    static func insertNodesAndSidebarLayersIntoDestinationGraph(destinationGraph: GraphEntity,
                                                                graphToInsert: GraphEntity,
                                                                // originalSidebarLayers: [SidebarLayerData],
                                                                focusedGroupNode: NodeId?,
                                                                // Copy-paste only; not for duplication
                                                                destinationGraphInfo: CopyPasteGraphDestinationInfo?,
                                                                // Option+Drag of a sidebar layer only
                                                                originalOptionDraggedLayer: SidebarListItemId?) -> (GraphEntity, NodeEntities, NodeIdMap) {
            
        // We want to keep everything about the destination graph (e.g. its id, rootUrl etc.)
        // and just add to its nodes and sidebar-layers
        var destinationGraphEntity: GraphEntity = destinationGraph
        
        // the graph entity that gets returned needs to be fundamentally
        
        // Change all IDs (nodes, sidebar layers)
        let (newGraphEntity, nodeIdMap) = graphToInsert.changeIds()
                
        let newNodeEntities = Self.updateCopiedNodesPositions(
            // Important: update the nodes-to-insert parent ids first,
            // since position update relies on checking "is this node at the destination graph's traversal level?"
            nodeEntities: Self.updateNodesParentIds(nodeEntities: newGraphEntity.nodes,
                                                    focusedGroupNode: focusedGroupNode),
            destinationGraphInfo: destinationGraphInfo)
        
        // Update nodes-to-insert and set them in the destination graph entity
        destinationGraphEntity.nodes += newNodeEntities
        
        // Update ordered-sidebar-layers-to-insert and set them in the destination graph entity
        destinationGraphEntity.orderedSidebarLayers = updateOrderedSidebarLayers(
            originalSidebarLayers: destinationGraphEntity.orderedSidebarLayers,
            newSidebarLayers: newGraphEntity.orderedSidebarLayers,
            nodeIdMap: nodeIdMap,
            originalOptionDraggedLayer: originalOptionDraggedLayer)
        
        
        // TODO: handle comment boxes
        
        return (destinationGraphEntity,
                newNodeEntities, // needed for updating just these pasted/duplicated nodes later
                nodeIdMap)
    }
    
    // Can we use this all the time now?
    @MainActor
    func insertNewComponent<T>(component: T,
                               encoder: (any DocumentEncodable)?,
                               copiedFiles: StitchDocumentDirectory,
                               
                               // If copy-paste, use destination project's offset, etc.
                               isCopyPaste: Bool,
                               
                               // Option + Dragging a layer in the sidebar
                               originalOptionDraggedLayer: SidebarListItemId? = nil,
                               
                               // Destination document, just like `self` is destination graph
                               document: StitchDocumentViewModel) where T: StitchComponentable {
        
        // MARK: Copy files first, since copied nodes may depend on these files
        if let encoder = encoder {
            encoder.importComponentFiles(copiedFiles)
        }
        
        // MARK: update the to-be-inserted node entities and sidebar layer data
        let (destinationGraphEntity, newNodes, nodeIdMap) = Self.insertNodesAndSidebarLayersIntoDestinationGraph(
            destinationGraph: self.createSchema(),
            graphToInsert: component.graphEntity,
            focusedGroupNode: document.groupNodeFocused?.groupNodeId,
            destinationGraphInfo: isCopyPaste ? document.copyPasteGraphDestinationInfo : nil,
            originalOptionDraggedLayer: nil)
        
        // MARK: create master component if any imported
        // Note: previously we created the master component *before* updating
        self.createMasterComponent(copiedFiles: copiedFiles, documentId: document.id)
        
        // MARK: actually 'insert' ("apply") the node entities and sidebar layer data to the this graph
        self.update(from: destinationGraphEntity)
        
        self.updateGraphAfterPaste(newNodes: newNodes,
                                   document: document,
                                   nodeIdMap: nodeIdMap,
                                   isOptionDragInSidebar: false)
    }
    
    @MainActor
    func createMasterComponent(copiedFiles: StitchDocumentDirectory,
                               documentId: GraphId) {
        
        if let decodedFiles = GraphDecodedFiles(importedFilesDir: copiedFiles) {
            // Update save location for components
            let components = decodedFiles.components.map { componentFromDecodedFiles in
                var componentFromDecodedFiles = componentFromDecodedFiles
                componentFromDecodedFiles.saveLocation = .localComponent(
                    GraphDocumentPath(docId: documentId.value,
                                      componentId: componentFromDecodedFiles.id,
                                      componentsPath: self.saveLocation))
                
                return componentFromDecodedFiles
            }
            
            let componentsDict = components.createComponentsDict(parentGraph: self)
            self.components = componentsDict.reduce(into: self.components) { result, newComponentEntry in
                result.updateValue(newComponentEntry.value, forKey: newComponentEntry.key)
            }
        } else {
            fatalErrorIfDebug()
        }
    }
    
    @MainActor
    static func updateCopiedNodesPositions(nodeEntities: NodeEntities,
                                           // nil = this was duplication, not copy-paste
                                           destinationGraphInfo: CopyPasteGraphDestinationInfo?) -> NodeEntities {
        
        // genuine copy-paste (Cmd C + Cmd V; Cmd X + Cmd V) places nodes in center of view-port
        if let destinationGraphInfo = destinationGraphInfo {
            return adjustPastedNodesPositions(
                pastedNodes: nodeEntities,
                destinationGraphOffset: destinationGraphInfo.destinationGraphOffset,
                destinationGraphFrame: destinationGraphInfo.destinationGraphFrame,
                destinationGraphScale: destinationGraphInfo.destinationGraphScale,
                destinationGraphTraversalLevel: destinationGraphInfo.destinationGraphTraversalLevel)
        }
        
        // else is duplication, which uses staggering strategy for node re-positioning
        else {
            
            // Update nodes in the follow ways:
            // 1. Stagger position
            // 2. Increment z-index
            return nodeEntities.map {
                // Update positional data
                $0.canvasEntityMap { node in
                    var node = node
                    node.position.shiftNodePosition()
                    node.zIndex += 1
                    return node
                }
            }
        }
    }
            
    @MainActor
    static func updateNodesParentIds(nodeEntities: NodeEntities,
                                     focusedGroupNode: NodeId?) -> [NodeEntity] {
        nodeEntities.map {
            $0.canvasEntityMap { (canvasEntity: CanvasNodeEntity) in
                var canvasEntity = canvasEntity
                // Note: suppose that the canvas item we copied from the origin project was actually in a group node, but we did not copy that group node.
                // The pasted canvas item will have `parentGroupNodeId = nil` since we did not bring its parent along.
                // TODO: write a test that demonstrates this
                if canvasEntity.parentGroupNodeId == nil {
                    canvasEntity.parentGroupNodeId = focusedGroupNode
                    return canvasEntity
                } else {
                    return canvasEntity
                }
            }
        }
    }
    
    @MainActor
    func updateGraphAfterPaste(newNodes: [NodeEntity],
                               document: StitchDocumentViewModel,
                               nodeIdMap: NodeIdMap,
                               isOptionDragInSidebar: Bool) {
        // Reset selected nodes
        self.resetSelectedCanvasItems()

        // Reset edit mode selections + inspector focus and actively-selected
        
        // We only want to do this if we actually copied a sidebar item
        let copiedAtleastOneLayer = newNodes.contains { $0.kind.isLayer }
        if copiedAtleastOneLayer {
            self.sidebarSelectionState.resetEditModeSelections()
        }
        
        self.layersSidebarViewModel.items.updateSidebarIndices()
        
        // NOTE: we can either duplicate layers OR patch nodes; but NEVER both
        // Update selected nodes
        newNodes
            .forEach { nodeEntity in
                switch nodeEntity.nodeTypeEntity {
                    
                case .patch, .group, .component:
                    if let canvasItem = self.getNodeViewModel(nodeEntity.id)?.nonLayerCanvasItem {
                        self.selectCanvasItem(canvasItem.id)
                    }
                    
                case .layer(let layerNode):
                    
                    // Actively-select the new layer node
                    let id = nodeEntity.id
                    
                    // If option dupe-dragging in the sidebar, only select the copied layers that correspond to the originally-primarily-selected layers.
                    // e.g. if we option dupe-dragged just a LayerGroup, primarily-select the LayerGroup and NOT all its children.
                    if isOptionDragInSidebar {
                        
                        // Note: nodeIdMap is `key: oldNode,  value: newNode`, so must do a reverse dictionary look up.
                        if let originalLayerNodeId = nodeIdMap.first(where: { $0.value == id })?.key,
                        self.sidebarSelectionState.originalLayersPrimarilySelectedAtStartOfOptionDrag.contains(originalLayerNodeId) {
                            
                            self.sidebarSelectionState.primary.insert(id)
                            self.layersSidebarViewModel.sidebarItemSelectedViaEditMode(id)
                        }
                    }
                    
                    // If not doing an sidebar option dupe-drag, just primarily-select the copied layer.
                    else {
                        self.sidebarSelectionState.primary.insert(id)
                        self.layersSidebarViewModel.sidebarItemSelectedViaEditMode(id)
                    }
                    
                    
                    // TODO: what is this?
                    self.updateInspectorFocusedLayers()
                    
                    // TODO: what is this?
                    layerNode.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                        
                        let portData = layerNode[keyPath: inputType.schemaPortKeyPath]
                        
                        let isPacked = portData.mode == .packed
                        
                        portData.allInputData.enumerated().forEach { portId, inputData in
                            let unpackedId = UnpackedPortType(rawValue: portId)
                            
                            // If unpacked, make sure we get valid ID
                            assertInDebug(isPacked || (!isPacked && unpackedId.isDefined))
                            
                            let portType: LayerInputKeyPathType = isPacked ? .packed : .unpacked(unpackedId ?? .port0)
                            let layerId = LayerInputType(layerInput: inputType, portType: portType)
                            if inputData.canvasItem != nil,
                               let canvasItem = self.getCanvasItem(.layerInput(.init(node: nodeEntity.id,
                                                                                     keyPath: layerId))) {
                                self.selectCanvasItem(canvasItem.id)
                            }
                        }
                    }
                }
        }
              
        removeCrossTraversalEdges(graph: self,
                                  document: document,
                                  for: newNodes.map(\.id).toSet)
    }
    
    // Duplicate ONLY the selected comment boxes
    func selectedCommentBoxesDuplicated() {
        // TODO: come back here
        return
        //        .stateOnly(
        //            duplicateSelectedCommentBoxes(
        //                graphSchema: graphSchema,
        //                graphState: graphState,
        //                // If we're duplicating ONLY comment boxes, we should deselect any selected nodes
        //                duplicatingCommentsOnly: true))
    }
}



/*
 Only wireless nodes and group splitters can have edges that cross traversal levels.
 */
// TODO: handle non-patch-node cases
@MainActor
func removeCrossTraversalEdges(graph: GraphState,
                               document: StitchDocumentViewModel,
                               for nodes: NodeIdSet) {
    
    // Establishes references
    // TODO: why weren't references already established? can avoid having to work with the weak var references here?
    graph.updateGraphData(document)
    
    for nodeId in nodes {
        
        guard let node = graph.getNode(nodeId),
              // TODO: handling layer inputs, components, group nodes ?
              let patchNode = node.patchNode else {
            continue
        }
        
        if patchNode.isWirelessOrGroupSplitterNode {
            continue
        }
                
        node.getAllInputsObservers().forEach { inputObserver in
            // If we have an upstream output...
            if let upstreamOutputObserverNodeId = inputObserver.upstreamOutputObserver?.id.nodeId,
               let upstreamNode = graph.getNode(upstreamOutputObserverNodeId)?.patchNodeViewModel,
               // ... that is not a wireless node or group splitter,
               !upstreamNode.isWirelessOrGroupSplitterNode,
               // and is on a different traversal level
               upstreamNode.parentGroupNodeId != patchNode.parentGroupNodeId {
                
                // ... then remove the connection
                inputObserver.removeUpstreamConnection(node: node)
            }
        }
        
        node.getAllOutputsObservers().forEach { outputObserver in
            outputObserver.getDownstreamInputsObservers().forEach { downstreamInputObserver in
                if let downstreamNode = graph.getNode(downstreamInputObserver.id.nodeId),
                   let downstreamPatchNode = downstreamNode.patchNodeViewModel,
                   !downstreamPatchNode.isWirelessOrGroupSplitterNode,
                   downstreamPatchNode.parentGroupNodeId != patchNode.parentGroupNodeId {
                    
                    downstreamInputObserver.removeUpstreamConnection(node: downstreamNode)
                }
            }
        }
    } // for node in nodes
    
    // update UI data etc.
    graph.updateGraphData(document)
}


extension PatchNodeViewModel {
    @MainActor
    var isWirelessOrGroupSplitterNode: Bool {
        if self.patch == .wirelessReceiver || self.patch == .wirelessReceiver {
            return true
        }
        
        if let splitterType = self.splitterType,
           splitterType != .inline {
            return true
        }
        
        return false
    }
}


@MainActor
func updateOrderedSidebarLayers(originalSidebarLayers: [SidebarLayerData],
                                newSidebarLayers: [SidebarLayerData],
                                nodeIdMap: NodeIdMap,
                                originalOptionDraggedLayer: SidebarListItemId?) -> [SidebarLayerData] {
    
    // Are we sidebar option dupe-dragging? If so, insert the duplicated layers immediately before the original option-dragged layer.
    if let originalOptionDraggedLayer = originalOptionDraggedLayer {
        
        guard let updatedLayers = attemptToInsertBeforeId(
            originalLayers: originalSidebarLayers,
            newLayers: newSidebarLayers,
            originalLayerId: originalOptionDraggedLayer) else {
            
            // If we were doing an option drag, we must able to do this
            fatalErrorIfDebug()
            return originalSidebarLayers
        }
        
        return updatedLayers
    }
    
    // Are we not sidebar option dupe-dragging, but pasting into the same project anyway? (e.g. regular duplication via sidebar)
    // If so, insert the duplicated layers after the top-most original sidebar layer.
    else if let copiedLayer = newSidebarLayers.first,
            let originalLayerId: NodeId = nodeIdMap.first(where: { $0.value == copiedLayer.id })?.key,
            originalSidebarLayers.getSidebarLayerDataIndex(originalLayerId).isDefined {
        
        return insertAfterId(data: originalSidebarLayers,
                             newDataList: newSidebarLayers,
                             afterId: originalLayerId)
    }
    
    // Otherwise, we're pasting sidebar layers into a completely different project and so will just add to front.
    else {
        // log("addComponentToGraph: will add to front")
        return newSidebarLayers + originalSidebarLayers
    }
}

//@MainActor
//func addComponentNodesAndSidebarLayers(to graph: GraphState,
//                                       newOrderedSidebarLayers: [SidebarLayerData],
//                                       newNodes: [NodeEntity],
//                                       nodeIdMap: NodeIdMap,
//                                       originalOptionDraggedLayer: SidebarListItemId? = nil) -> GraphEntity {
//    
//    var graphEntity: GraphEntity = graph.createSchema()
//    
//    
//    // Add new nodes
//    graphEntity.nodes += newNodes
//    
//    // Are we sidebar option dupe-dragging? If so, insert the duplicated layers immediately before the original option-dragged layer.
//    if let originalOptionDraggedLayer = originalOptionDraggedLayer {
//        if let updatedLayers = attemptToInsertBeforeId(
//            originalLayers: graphEntity.orderedSidebarLayers,
//            newLayers: newOrderedSidebarLayers,
//            originalLayerId: originalOptionDraggedLayer) {
//            
//            graphEntity.orderedSidebarLayers = updatedLayers
//        } else {
//            fatalErrorIfDebug()
//        }
//        return graphEntity
//    }
//    
//            // Are we not sidebar option dupe-dragging, but pasting into the same project anyway? (e.g. regular duplication via sidebar)
//    // If so, insert the duplicated layers after the top-most original sidebar layer.
//    else if let copiedLayer = newOrderedSidebarLayers.first,
//            let originalLayerId: NodeId = nodeIdMap.first(where: { $0.value == copiedLayer.id })?.key,
//            graphEntity.orderedSidebarLayers.getSidebarLayerDataIndex(originalLayerId).isDefined {
//        
//        graphEntity.orderedSidebarLayers = insertAfterID(
//            data: graphEntity.orderedSidebarLayers,
//            newDataList: newOrderedSidebarLayers,
//            afterID: originalLayerId)
//        
//        return graphEntity
//    }
//    
//    // Otherwise, we're pasting sidebar layers into a completely different project and so will just add to front.
//    else {
//        // log("addComponentToGraph: will add to front")
//        graphEntity.orderedSidebarLayers = newOrderedSidebarLayers + graphEntity.orderedSidebarLayers
//        return graphEntity
//    }
//}

extension StitchDocumentViewModel {
    @MainActor
    var copyPasteGraphDestinationInfo: CopyPasteGraphDestinationInfo {
        .init(destinationGraphOffset: self.localPosition,
              destinationGraphFrame: self.frame,
              destinationGraphScale: self.graphMovement.zoomData,
              destinationGraphTraversalLevel: self.groupNodeFocused?.groupNodeId)
    }
}
