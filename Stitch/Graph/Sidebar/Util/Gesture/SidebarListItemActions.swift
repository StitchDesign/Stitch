//
//  SidebarListItemActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

extension GraphUIState {
    func sidebarLayerHovered(layerId: LayerNodeId) {
        self.highlightedSidebarLayers.insert(layerId)
    }

    func sidebarLayerHoverEnded(layerId: LayerNodeId) {
        self.highlightedSidebarLayers.remove(layerId)
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

    let clickedId: NodeId

    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        state.layerHiddenStatusToggled(clickedId)
        return .persistenceResponse
    }
}

struct SelectedLayersVisiblityUpdated: GraphEventWithResponse {

    let selectedLayers: NodeIdSet
    let newVisibilityStatus: Bool
    
    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        for selectedLayer in selectedLayers {
            state.layerHiddenStatusToggled(selectedLayer,
                                           newVisibilityStatus: newVisibilityStatus)
        }
        return .persistenceResponse
    }
}

extension GraphState {
    @MainActor
    func layerHiddenStatusToggled(_ clickedId: NodeId,
                                  // If provided, then we are explicitly setting true/false (for multiple layers) as opposed to just toggling an individual layer
                                  newVisibilityStatus: Bool? = nil) {

        guard let layerNode = self.getLayerNode(id: clickedId)?.layerNode else {
            log("SidebarItemHiddenStatusToggled: could not find layer node for clickedId \(clickedId.id)")
            fatalErrorIfDebug() // Is this bad?
            return
        }
        
        let descendants = self.getDescendants(for: clickedId.asLayerNodeId)

        if let newVisibilityStatus = newVisibilityStatus {
            layerNode.hasSidebarVisibility = newVisibilityStatus
        } else {
            layerNode.hasSidebarVisibility.toggle()
        }
        
        let isShown = layerNode.hasSidebarVisibility
        
        for id in descendants {
            self.getLayerNode(id: id.id)?.layerNode?.hasSidebarVisibility = isShown
        }
    }
}
