//
//  SidebarListItemActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

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
struct SelectedLayersVisiblityUpdated: GraphEventWithResponse {

    let selectedLayers: NodeIdSet
    var newVisibilityStatus: Bool? = nil // nil = toggled
    
    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        
        guard let document = state.documentDelegate else {
            fatalErrorIfDebug()
            return .noChange
        }
        
        for selectedLayer in selectedLayers {
            state.layerHiddenStatusToggled(selectedLayer,
                                           newVisibilityStatus: newVisibilityStatus)
        }
        
        // TODO: why do we have to immediately update the preview layers? Why isn't setting `state.shouldResortPreviewLayers = true` enough?
        state.shouldResortPreviewLayers = true
        state.updateOrderedPreviewLayers(activeIndex: document.activeIndex)
        
        return .persistenceResponse
    }
}

extension GraphState {
    @MainActor
    func layerHiddenStatusToggled(_ clickedId: NodeId,
                                  // If provided, then we are explicitly setting true/false (for multiple layers) as opposed to just toggling an individual layer
                                  newVisibilityStatus: Bool? = nil) {

        guard let layerNode = self.getLayerNode(clickedId) else {
            log("layerHiddenStatusToggled: could not find layer node for clickedId \(clickedId.id)")
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
            self.getLayerNode(id.id)?.hasSidebarVisibility = isShown
        }
        
        // TODO: introduce an `Enabled` input on layer node and update `LayerInputPort.shouldResortPreviewLayersIfChanged`
        // See `LayerInputPort.shouldResortPreviewLayersIfChanged` for which inputs' changes require resorting
        self.shouldResortPreviewLayers = true
    }
}
