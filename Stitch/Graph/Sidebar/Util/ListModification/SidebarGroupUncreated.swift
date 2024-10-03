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
        state.sidebarGroupUncreatedViaEditMode()
        return .init(willPersist: true)
    }
}

extension GraphState {
    
    @MainActor
    func sidebarGroupUncreatedViaEditMode() {
        log("_SidebarGroupUncreated called")

        let primarilySelectedGroups = self.sidebarSelectionState.primary
        
        guard let group = primarilySelectedGroups.first else {
            // Expected group here
            fatalErrorIfDebug()
            return
        }
        
        // let children = self.orderedSidebarLayers.get(group.id)?.children ?? []
        let children = self.orderedSidebarLayers.getSidebarLayerData(group.id)?.children ?? []
        
        let newParentId = self.getNodeViewModel(group.asNodeId)?.layerNode?.layerGroupId

        // Update sidebar self
        self.orderedSidebarLayers = self.orderedSidebarLayers.ungroup(selectedGroupId: group.asNodeId)

        // find each child of the group, set its layer group id to the parent of the selected group
        children.forEach { child in
            if let layerNode = self.getNodeViewModel(child.id) {
                layerNode.layerNode?.layerGroupId = newParentId
            }
        }

        // finally, delete layer group node itself (but not its children)
        self.deleteNode(id: group.id, willDeleteLayerGroupChildren: false)

        // update legacy sidebar data
        self.updateSidebarListStateAfterStateChange()
        
        // reset selection-state
        self.sidebarSelectionState = .init()
    }
}
