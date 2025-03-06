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
        Task(priority: .high) { [weak state] in
            await state?.duplicateShortcutKeyPressed()
        }
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

extension StitchDocumentViewModel {
    @MainActor
    func duplicateShortcutKeyPressed() async {
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
                
            await self.visibleGraph
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
                               document: StitchDocumentViewModel) async where T: StitchComponentable {
        await self.insertNewComponent(component: copiedComponentResult.component,
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
                               document: StitchDocumentViewModel) async where T: StitchComponentable {
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
            await encoder.importComponentFiles(copiedFiles)
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
        
        await self.updateAsync(from: graph)
        
        self.updateGraphAfterPaste(newNodes: newNodes)
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
                                isOptionDragInSidebar: Bool = false) -> GraphEntity where T: StitchComponentable {
        var graph: GraphEntity = self.createSchema()
        
        // Add new nodes
        graph.nodes += newNodes
        
        // TODO: how to handle the duplication-insertion of sidebar layers' during an option+drag gesture?
        // Why can't we just use the same logic as regular copy-paste/duplication, i.e. `insertAfterID` ?
        if isOptionDragInSidebar {
            log("GraphState: addComponentToGraph: had option drag in sidebar, will add duplicated layers to front")
            graph.orderedSidebarLayers = newComponent.orderedSidebarLayers + graph.orderedSidebarLayers
            return graph
        }
        
        guard let firstCopiedLayer = newComponent.graph.orderedSidebarLayers.first else {
            log("GraphState: addComponentToGraph: did not copy or duplicate any sidebar layers")
            return graph
        }
        
        // Are we pasting into the same project where the copied sidebar layers came from?
        // If so, then we should insert the copied sidebar layers after that original sidebar layer.
        if let originalLayerId: NodeId = nodeIdMap.first(where: { $0.value == firstCopiedLayer.id })?.key,
           graph.orderedSidebarLayers.getSidebarLayerDataIndex(originalLayerId).isDefined {
            
            // Note: is this really correct for cases where we have a nested layer group in the sidebar? ... Should be, because nested?
            graph.orderedSidebarLayers = insertAfterID(
                data: graph.orderedSidebarLayers,
                newDataList: newComponent.graph.orderedSidebarLayers,
                afterID: originalLayerId)
            
            return graph
        }
        
        // Otherwise, we're pasting sidebar layers into a completely different project and so will just add to front.
        else {
            graph.orderedSidebarLayers = newComponent.orderedSidebarLayers + graph.orderedSidebarLayers
            return graph
        }
    }
    
    @MainActor
    func updateGraphAfterPaste(newNodes: [NodeEntity]) {
        // Reset selected nodes
        self.resetSelectedCanvasItems()

        // Reset edit mode selections + inspector focus and actively-selected
        self.sidebarSelectionState.resetEditModeSelections()
        // self.sidebarSelectionState.primary = .init()
        
        // NOTE: we can either duplicate layers OR patch nodes; but NEVER both
        // Update selected nodes
        newNodes
            .forEach { nodeEntity in
                switch nodeEntity.nodeTypeEntity {
                    
                case .layer(let layerNode):
                    
                    // Actively-select the new layer node
                    let id = nodeEntity.id
                    self.sidebarSelectionState.primary.insert(id)
                                        
                    self.layersSidebarViewModel.sidebarItemSelectedViaEditMode(id)
                    
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
                            if let canvas = inputData.canvasItem,
                               let canvasItem = self.getCanvasItem(.layerInput(.init(node: nodeEntity.id,
                                                                                     keyPath: layerId))) {
                                canvasItem.select(self)
                            }
                        }
                    }
                    
                case .patch, .group, .component:
                    let stitch = self.getNodeViewModel(nodeEntity.id)
                    if let canvasItem = stitch?.patchCanvasItem {
                        canvasItem.select(self)
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
