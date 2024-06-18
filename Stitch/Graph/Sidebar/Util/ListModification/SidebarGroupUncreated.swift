//
//  SidebarGroupUncreated.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// eg we had only groups selected, and pressed 'ungroup'

// note: see `_SidebarGroupUncreated` for new stuff to do e.g. `syncSidebarDataWithNodes`
struct SidebarGroupUncreated: GraphEventWithResponse {
    func handle(state: GraphState) -> GraphResponse {
        
        log("_SidebarGroupUncreated called")

        let primarilySelectedGroups = state.sidebarSelectionState.primary
        
        guard let group = primarilySelectedGroups.first else {
            // Expected group here
            fatalErrorIfDebug()
            return .noChange
        }
        
        let children = state.orderedSidebarLayers.get(group.id)?.children ?? []
        let newParentId = state.getNodeViewModel(group.asNodeId)?.layerNode?.layerGroupId

        // Update sidebar state
        state.orderedSidebarLayers = state.orderedSidebarLayers.ungroup(selectedGroupId: group.asNodeId)

        // find each child of the group, set its layer group id to the parent of the selected group
        children.forEach { child in
            if let layerNode = state.getNodeViewModel(child.id) {
                layerNode.layerNode?.layerGroupId = newParentId
            }
        }

        // finally, delete layer group node itself (but not its children)
        state.deleteNode(id: group.id, willDeleteLayerGroupChildren: false)

        // update legacy sidebar data
        state.updateSidebarListStateAfterStateChange()
        
        // reset selection-state
        state.sidebarSelectionState = .init()
        
        return .init(willPersist: true)
    }
}
