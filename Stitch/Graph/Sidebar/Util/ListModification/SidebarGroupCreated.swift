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
struct SidebarGroupCreated: GraphEventWithResponse {

    func handle(state: GraphState) -> GraphResponse {
        log("_createLayerGroup called")
        
        // Create node view model for the new Layer Group
        
        let newNode = Layer.group.layerGraphNode.createViewModel(
            position: state.newNodeCenterLocation,
            zIndex: state.highestZIndex + 1,
            activeIndex: .defaultActiveIndex,
            graphDelegate: state)
        
        let primarilySelectedLayers = state.sidebarSelectionState.primary.map { $0.asNodeId }.toSet
        
        // Are any of these selections already part of a group?
        // If so, the newly created LayerGroup will have that group as its own parent (layerGroupId).
        let existingParentForSelections = state.layerGroupForSelections(primarilySelectedLayers)
        
        guard let newGroupData = state.orderedSidebarLayers
            .createGroup(newGroupId: newNode.id,
                         parentLayerGroupId: existingParentForSelections,
                         selections: primarilySelectedLayers) else {
            fatalErrorIfDebug()
            return .noChange
        }
        
//        newNode.adjustPosition(center: state.newNodeCenterLocation)
        newNode.graphDelegate = state // redundant?
                
        // Add to state
        let _ = state.nodeCreated(node: newNode)
            
        // Update sidebar state
        state.orderedSidebarLayers.insertGroup(group: newGroupData,
                                               selections: primarilySelectedLayers)
        
        newNode.layerNode?.layerGroupId = existingParentForSelections
        
        // Newly created groups start out expanded:
        newNode.layerNode?.isExpandedInSidebar = true
        
        // Iterate through primarly selected layers,
        // assigning new LG as their layerGoupId.
        primarilySelectedLayers.forEach { layerId in
            if let layerNode = state.getLayerNode(id: layerId)?.layerNode {
                layerNode.layerGroupId = newNode.id
            }
        }
        
        // Update legacy state
        state.updateSidebarListStateAfterStateChange()
        
        // Reset selections
        state.sidebarSelectionState.resetSelections()
        
        // NOTE: must do this AFTER children have been assigned to the new layer node; else we return preview window size
        
        // TODO: adjust position of children
        // TODO: determine real size of just-created LayerGroup
        let groupFit: LayerGroupFit = state.getLayerGroupFit(
            primarilySelectedLayers,
            parentSize: state.getParentSizeForSelectedNodes(selectedNodes: primarilySelectedLayers))
        
        let assumedLayerGroupSize: LayerSize = groupFit.size
        
        // Update layer group's size input
        newNode.getInputRowObserver(1)?.updateValues([.size(assumedLayerGroupSize)])
        
        
        
        return .persistenceResponse
    }
}

extension GraphState {
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
