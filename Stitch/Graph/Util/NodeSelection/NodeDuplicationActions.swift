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
       func insertingAfterID(_ newDataList: [SidebarLayerData], afterID: UUID) -> SidebarLayerData {
           // If there are no children, return the current structure as-is
           guard let children = children else {
               return self
           }
           
           var modifiedChildren = [SidebarLayerData]()
           
           for child in children {
               // If the current child's id matches afterID, insert all items from newDataList right after it
               if child.id == afterID {
                   modifiedChildren.append(child)
                   modifiedChildren.append(contentsOf: newDataList)
               } else {
                   // Otherwise, continue recursively in the child's children
                   modifiedChildren.append(child.insertingAfterID(newDataList, afterID: afterID))
               }
           }
           
           // Return a new SidebarLayerData instance with the modified children
           return SidebarLayerData(id: id, children: modifiedChildren)
       }

}

// Wrapper function to handle the insertion at the top level, returning a modified array
func insertAfterID(data: [SidebarLayerData], newDataList: [SidebarLayerData], afterID: UUID) -> [SidebarLayerData] {
    var modifiedData = [SidebarLayerData]()
    
    for item in data {
        // If the top-level item's id matches afterID, insert all items from newDataList after it
        if item.id == afterID {
            modifiedData.append(item)
            modifiedData.append(contentsOf: newDataList)
        } else {
            // Otherwise, apply insertion in the item's children recursively
            modifiedData.append(item.insertingAfterID(newDataList, afterID: afterID))
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
                groupNodeFocused: self.graphUI.groupNodeFocused,
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
    func insertNewComponent<T>(component: T,
                               encoder: (any DocumentEncodable)?,
                               copiedFiles: StitchDocumentDirectory,
                               isCopyPaste: Bool,
                               document: StitchDocumentViewModel) where T: StitchComponentable {
        let (newComponent, nodeIdMap) = Self.updateCopiedNodes(
            component: component,
            destinationGraphInfo: isCopyPaste ?
                .init(destinationGraphOffset: self.localPosition,
                      destinationGraphFrame: document.frame,
                      destinationGraphScale: self.graphMovement.zoomData,
                      destinationGraphTraversalLevel: document.groupNodeFocused?.groupNodeId) : nil
        )
        
        guard let document = self.documentDelegate else {
            return
        }
        
        // Copy files before inserting component
        if let encoder = encoder {
            encoder.importComponentFiles(copiedFiles)
        }
        
        // Update top-level nodes to match current focused group
        let newNodes: [NodeEntity] = Self.createNewNodes(
            from: newComponent,
            focusedGroupNode: document.groupNodeFocused?.groupNodeId
        )
        
        let graph: GraphEntity = self.addComponentToGraph(newComponent: newComponent,
                                                          newNodes: newNodes,
                                                          nodeIdMap: nodeIdMap)
        
        // Create master component if any imported
        if let decodedFiles = GraphDecodedFiles(importedFilesDir: copiedFiles) {
            // Update save location for components
            let components = decodedFiles.components.map { component in
                var component = component
                component.saveLocation = .localComponent(.init(docId: document.id,
                                                               componentId: component.id,
                                                               componentsPath: self.saveLocation))
                return component
            }
            
            let componentsDict = components.createComponentsDict(parentGraph: self)
            self.components = componentsDict.reduce(into: self.components) { result, newComponentEntry in
                result.updateValue(newComponentEntry.value, forKey: newComponentEntry.key)
            }
        } else {
            fatalErrorIfDebug()
        }
        
        self.update(from: graph)
        
        self.updateGraphAfterPaste(newNodes: newNodes,
                                   nodeIdMap: nodeIdMap,
                                   isOptionDragInSidebar: false)
    }
    
    @MainActor
    static func updateCopiedNodes<T>(component: T,
                                     // nil = this was duplication, not copy-paste
                                     destinationGraphInfo: CopyPasteGraphDestinationInfo?) -> (T, NodeIdMap) where T: StitchComponentable {
        // Change all IDs
        var newComponent = component
        let (newGraph, nodeIdMap) = newComponent.graph.changeIds()
        newComponent.graph = newGraph
        
        // genuine copy-paste (Cmd C + Cmd V; Cmd X + Cmd V) places nodes in center of view-port
        if let destinationGraphInfo = destinationGraphInfo {
            newComponent.graph.nodes = adjustPastedNodesPositions(
                pastedNodes: newComponent.graph.nodes,
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
            newComponent.graph.nodes = newComponent.nodes.map {
                // Update positional data
                $0.canvasEntityMap { node in
                    var node = node
                    node.position.shiftNodePosition()
                    node.zIndex += 1
                    return node
                }
            }
        }
        
        return (newComponent, nodeIdMap)
    }
    
    @MainActor
    static func createNewNodes<T>(from newComponent: T,
                                  focusedGroupNode: NodeId?) -> [NodeEntity] where T: StitchComponentable {
        newComponent.nodes.map {
            $0.canvasEntityMap { canvasItem in
                var canvasItem = canvasItem
                // Note: suppose that the canvas item we copied from the origin project was actually in a group node, but we did not copy that group node.
                // The pasted canvas item will have `parentGroupNodeId = nil` since we did not bring its parent along.
                // TODO: write a test that demonstrates this
                if canvasItem.parentGroupNodeId == nil {
                    canvasItem.parentGroupNodeId = focusedGroupNode
                    return canvasItem
                } else {
                    return canvasItem
                }
            }
        }
    }
    
    // make this top level?
    // And call it "add nodes and sidebar layers" to the graph
    
    // fka `duplicateCopiedNodes`
    @MainActor
    func addComponentToGraph<T>(newComponent: T,
                                newNodes: [NodeEntity],
                                nodeIdMap: NodeIdMap,
                                originalOptionDraggedLayer: SidebarListItemId? = nil) -> GraphEntity where T: StitchComponentable {
        var graph: GraphEntity = self.createSchema()
        
        // Add new nodes
        graph.nodes += newNodes
    
        // Are we sidebar option dupe-dragging? If so, insert the duplicated layers immediately before the original option-dragged layer.
        if let originalOptionDraggedLayer = originalOptionDraggedLayer {
            
            // log("addComponentToGraph: addComponentToGraph: will attempt to insert before \(originalOptionDraggedLayer)")
            
            if let updatedLayers = attemptToInsertBeforeId(
                originalLayers: graph.orderedSidebarLayers,
                newLayers: newComponent.graph.orderedSidebarLayers,
                originalLayerId: originalOptionDraggedLayer) {
                
                graph.orderedSidebarLayers = updatedLayers
            } else {
                fatalErrorIfDebug()
            }
            
            return graph
        }
        
                // Are we not sidebar option dupe-dragging, but pasting into the same project anyway? (e.g. regular duplication via sidebar)
        // If so, insert the duplicated layers after the top-most original sidebar layer.
        else if let copiedLayer = newComponent.graph.orderedSidebarLayers.first,
                let originalLayerId: NodeId = nodeIdMap.first(where: { $0.value == copiedLayer.id })?.key,
                graph.orderedSidebarLayers.getSidebarLayerDataIndex(originalLayerId).isDefined {
            
            // log("addComponentToGraph: will insert after \(originalLayerId)")
            graph.orderedSidebarLayers = insertAfterID(
                data: graph.orderedSidebarLayers,
                newDataList: newComponent.graph.orderedSidebarLayers,
                afterID: originalLayerId)
            
            return graph
        }
        
        // Otherwise, we're pasting sidebar layers into a completely different project and so will just add to front.
        else {
            // log("addComponentToGraph: will add to front")
            graph.orderedSidebarLayers = newComponent.orderedSidebarLayers + graph.orderedSidebarLayers
            return graph
        }
    }
    
    @MainActor
    func updateGraphAfterPaste(newNodes: [NodeEntity],
                               nodeIdMap: NodeIdMap,
                               isOptionDragInSidebar: Bool) {
        // Reset selected nodes
        self.resetSelectedCanvasItems()

        // Reset edit mode selections + inspector focus and actively-selected
        self.sidebarSelectionState.resetEditModeSelections()
        // self.sidebarSelectionState.primary = .init()
        
        self.layersSidebarViewModel.items.updateSidebarIndices()
        
        // NOTE: we can either duplicate layers OR patch nodes; but NEVER both
        // Update selected nodes
        newNodes
            .forEach { nodeEntity in
                switch nodeEntity.nodeTypeEntity {
                    
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
                    
                    
                    self.updateInspectorFocusedLayers()
                    
                    layerNode.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                        
                        let portData = layerNode[keyPath: inputType.schemaPortKeyPath]
                        
                        let isPacked = portData.mode == .packed
                        
                        portData.allInputData.enumerated().forEach { portId, inputData in
                            let unpackedId = UnpackedPortType(rawValue: portId)
                            
                            // If unpacked, make sure we get valid ID
                            assertInDebug(isPacked || (!isPacked && unpackedId.isDefined))
                            
                            let portType: LayerInputKeyPathType = isPacked ? .packed : .unpacked(unpackedId ?? .port0)
                            let layerId = LayerInputType(layerInput: inputType,
                                                         portType: portType)
                            if inputData.canvasItem != nil,
                               let canvasItem = self.getCanvasItem(.layerInput(.init(node: nodeEntity.id,
                                                                                     keyPath: layerId))) {
                                self.selectCanvasItem(canvasItem.id)
                            }
                        }
                    }
                    
                case .patch, .group, .component:
                    
                    if let canvasItem = self.getNodeViewModel(nodeEntity.id)?.patchCanvasItem {
                        self.selectCanvasItem(canvasItem.id)
                    }
                }
        }
                
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
