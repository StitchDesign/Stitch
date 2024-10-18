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
struct SidebarGroupCreated: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {
        log("SidebarGroupCreated called")
        
        // Create node view model for the new Layer Group
        
        let newNode = Layer.group.layerGraphNode.createViewModel(
            position: state.newNodeCenterLocation,
            zIndex: state.visibleGraph.highestZIndex + 1,
            graphDelegate: state.visibleGraph)
        
        let primarilySelectedLayers = state.visibleGraph.sidebarSelectionState.primary.map { $0.asNodeId }.toSet
        
        // Are any of these selections already part of a group?
        // If so, the newly created LayerGroup will have that group as its own parent (layerGroupId).
        let existingParentForSelections = state.visibleGraph.layerGroupForSelections(primarilySelectedLayers)
        
        guard let newGroupData = state.visibleGraph.orderedSidebarLayers
            .createGroup(newGroupId: newNode.id,
                         parentLayerGroupId: existingParentForSelections,
                         selections: primarilySelectedLayers) else {
            fatalErrorIfDebug()
            return
        }
        
//        newNode.adjustPosition(center: state.newNodeCenterLocation)
        newNode.graphDelegate = state.visibleGraph // redundant?
                
        // Add to state
        state.nodeCreated(node: newNode)
            
        // Update sidebar state
        state.visibleGraph.orderedSidebarLayers.insertGroup(group: newGroupData,
                                               selections: primarilySelectedLayers)
        
        newNode.layerNode?.layerGroupId = existingParentForSelections
        
        // Newly created groups start out expanded:
        newNode.layerNode?.isExpandedInSidebar = true
        
        // Iterate through primarly selected layers,
        // assigning new LG as their layerGoupId.
        primarilySelectedLayers.forEach { layerId in
            if let layerNode = state.visibleGraph.getLayerNode(id: layerId)?.layerNode {
                layerNode.layerGroupId = newNode.id
            }
        }
        
        // Update legacy state
        state.visibleGraph.updateSidebarListStateAfterStateChange()
        
        // Only reset edit mode selections if we're explicitly in edit mode (i.e. on iPad)
        if state.graph.sidebarSelectionState.isEditMode {
            // Reset selections
            state.visibleGraph.sidebarSelectionState.resetEditModeSelections()
        }

        
        // NOTE: must do this AFTER children have been assigned to the new layer node; else we return preview window size
        
        // TODO: adjust position of children
        // TODO: determine real size of just-created LayerGroup
        let groupFit: LayerGroupFit = state.visibleGraph.getLayerGroupFit(
            primarilySelectedLayers,
            parentSize: state.visibleGraph.getParentSizeForSelectedNodes(selectedNodes: primarilySelectedLayers))

        // TODO: any reason to not use .auto x .auto for a nearly created group? ... perhaps for .background, which can become too big in a group whose children use .position modifiers?
        // TODO: how important is the LayerGroupFit.adjustment/offset etc. ?
//        let assumedLayerGroupSize: LayerSize = groupFit.size
//        let assumedLayerGroupSize: LayerSize = .init(width: .auto, height: .auto)
        // Note: layer groups start out with `size = fill` rather than `size = hug` because orientation
        let assumedLayerGroupSize: LayerSize = .init(width: .fill, height: .fill)
        
        // Update layer group's size input
        newNode.layerNode?.sizePort.updatePortValues([.size(assumedLayerGroupSize)])
                
        state.visibleGraph.persistNewNode(newNode)
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
