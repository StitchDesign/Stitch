//
//  SidebarGroupCreated.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// when a sidebar group is created from a selection of sidebar items,
// we should insert the group at the location of the
extension LayersSidebarViewModel {
    @MainActor
    func sidebarGroupCreated() {
        log("SidebarGroupCreated called")
        
        guard let graph = self.graphDelegate,
              let state = graph.documentDelegate else {
            return
        }
        
        // Create node view model for the new Layer Group
        
        let newNode = Layer.group.layerGraphNode.createViewModel(
            position: state.newNodeCenterLocation,
            zIndex: graph.highestZIndex + 1,
            graphDelegate: graph)
        
        let primarilySelectedLayers: Set<SidebarListItemId> = self.primary
        
        let candidateGroup = self.items.containsValidGroup(from: primarilySelectedLayers)
        
        guard let newGroupData = self.items
            .createGroup(newGroupId: newNode.id,
                         parentLayerGroupId: candidateGroup.parentId,
                         selections: primarilySelectedLayers) else {
            fatalErrorIfDebug()
            return
        }
        
//        newNode.adjustPosition(center: state.newNodeCenterLocation)
        newNode.graphDelegate = graph // redundant?
                
        // Add to state
        state.nodeCreated(node: newNode)
            
        // Update sidebar state
        self.items.insertGroup(group: newGroupData,
                               selections: primarilySelectedLayers)
   
        self.items.updateSidebarIndices()
        
        // Only reset edit mode selections if we're explicitly in edit mode (i.e. on iPad)
        if self.isEditing {
            // Reset selections
            self.selectionState.resetEditModeSelections()
        }
        
        // Focus this, and only this, layer node in inspector
        self.selectionState.resetEditModeSelections()
        self.sidebarItemSelectedViaEditMode(newNode.id)
        self.selectionState.lastFocused = newNode.id
        self.graphDelegate?.deselectAllCanvasItems()
        
        // NOTE: must do this AFTER children have been assigned to the new layer node; else we return preview window size
        
        // TODO: adjust position of children
        // TODO: determine real size of just-created LayerGroup
//        let groupFit: LayerGroupFit = graph.getLayerGroupFit(
//            primarilySelectedLayers,
//            parentSize: graph.getParentSizeForSelectedNodes(selectedNodes: primarilySelectedLayers))

        // TODO: any reason to not use .auto x .auto for a nearly created group? ... perhaps for .background, which can become too big in a group whose children use .position modifiers?
        // TODO: how important is the LayerGroupFit.adjustment/offset etc. ?
//        let assumedLayerGroupSize: LayerSize = groupFit.size
//        let assumedLayerGroupSize: LayerSize = .init(width: .auto, height: .auto)
        // Note: layer groups start out with `size = fill` rather than `size = hug` because orientation
        let assumedLayerGroupSize: LayerSize = .init(width: .fill, height: .fill)
        
        // Update layer group's size input
        newNode.layerNode?.sizePort.updatePortValues([.size(assumedLayerGroupSize)])
                
        graph.persistNewNode(newNode)
    }
}

extension GraphState {
    @MainActor
    func layerGroupForSelections(_ selections: NodeIdSet) -> NodeId? {

         // Assumes `selections` all have single parent;
         // this is guaranteed by the way we select layers in the sidebar
         // TODO: is it possible to primarily-select a

         var parentId: NodeId?
         selections.forEach { layerId in
             if let layerNode = self.getLayerNode(id: layerId),
                let parent = layerNode.layerNode?.layerGroupId {
                 parentId = parent
             }
         }

         log("layerGroupForSelections: parentId: \(parentId)")

         return parentId
     }
  }
