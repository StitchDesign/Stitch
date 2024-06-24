//
//  SidebarListItemActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

struct SidebarLayerHovered: GraphUIEvent {
    let layer: LayerNodeId
    
    func handle(state: GraphUIState) {
        state.highlightedSidebbarLayers.insert(layer)
    }
}

struct SidebarLayerHoverEnded: GraphUIEvent {
    let layer: LayerNodeId
    
    func handle(state: GraphUIState) {
        state.highlightedSidebbarLayers.remove(layer)
    }
}


/*
 "Sidebar item's hide-icon clicked"

 If item not-hidden or only secondary-hidden:
 - primary-hides item
 - if item was group, must also secondary-hide all descendants

 If primary-hidden:
 - un-hides item
 - un-hides item's secondarily-hidden descendants
 (DOES NOT un-hide primarily-hidden descendants)
 */
struct SidebarItemHiddenStatusToggled: GraphEventWithResponse {

    let clickedId: LayerNodeId

    func handle(state: GraphState) -> GraphResponse {

        let sidebarGroups = state.getSidebarGroupsDict()
        
        let descendants: LayerIdSet = getDescendantsIds(
            id: clickedId,
            groups: sidebarGroups,
            acc: LayerIdSet())

        guard let layerNode = state.getLayerNode(id: clickedId.id)?.layerNode else {
            log("SidebarItemHiddenStatusToggled: could not find layer node for clickedId \(clickedId.id)")
            return .noChange
        }
                
        layerNode.hasSidebarVisibility.toggle()
        
        let isShown = layerNode.hasSidebarVisibility
        
        for id in descendants {
            state.getLayerNode(id: id.id)?.layerNode?.hasSidebarVisibility = isShown
        }
        
        return .persistenceResponse
    }
}
