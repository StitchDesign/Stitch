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
        state.highlightedSidebarLayers.insert(layer)
    }
}

struct SidebarLayerHoverEnded: GraphUIEvent {
    let layer: LayerNodeId
    
    func handle(state: GraphUIState) {
        state.highlightedSidebarLayers.remove(layer)
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

    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        state.layerHiddenStatusToggled(clickedId)
        return .persistenceResponse
    }
}

// TODO: how to handle 'toggling' hidden status when multiple layers are selected and each layer may already have its own hidden status? ... Should user explicitly pick "Hide Layer" vs "Unhide Layer"?
struct SelectedLayersHiddenStatusToggled: GraphEventWithResponse {

    let selectedLayers: LayerIdSet
    
    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        // Careful -- some of these layers may be descendants of each other, and we currently toggle the descendants' status as well
        for selectedLayer in selectedLayers {
            state.layerHiddenStatusToggled(selectedLayer)
        }
        return .persistenceResponse
    }
}

extension GraphState {
    @MainActor
    func layerHiddenStatusToggled(_ clickedId: LayerNodeId) {
        
        guard let layerNode = self.getLayerNode(id: clickedId.id)?.layerNode else {
            log("SidebarItemHiddenStatusToggled: could not find layer node for clickedId \(clickedId.id)")
            fatalErrorIfDebug() // Is this bad?
            return
        }
        
        let sidebarGroups = self.getSidebarGroupsDict()
        
        let descendants: LayerIdSet = getDescendantsIds(
            id: clickedId,
            groups: sidebarGroups,
            acc: LayerIdSet())

        layerNode.hasSidebarVisibility.toggle()
        
        let isShown = layerNode.hasSidebarVisibility
        
        for id in descendants {
            self.getLayerNode(id: id.id)?.layerNode?.hasSidebarVisibility = isShown
        }
    }
}
