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
extension ProjectSidebarObservable {
    @MainActor
    func sidebarGroupUncreated() {
        let primarilySelectedGroups = self.selectionState.primary
        let encodedData = self.createdOrderedEncodedData()
        
        guard let group = primarilySelectedGroups.first,
              let item = self.items.get(group) else {
            // Expected group here
            fatalErrorIfDebug()
            return
        }
        
        let children = item.children ?? []
        
        // Update sidebar self
        let newEncodedData = encodedData.ungroup(selectedGroupId: group)
        
        // reset selection-state
        self.selectionState.resetEditModeSelections()
        
        self.sidebarGroupUncreatedViaEditMode(groupId: group,
                                              children: children.map(\.id))

        self.persistSidebarChanges(encodedData: newEncodedData)
    }
}

extension LayersSidebarViewModel {
    
    @MainActor
    func sidebarGroupUncreatedViaEditMode(groupId: NodeId, children: [NodeId]) {
        log("_SidebarGroupUncreated called")

        guard let graph = self.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let newParentId = graph.getNodeViewModel(groupId)?.layerNode?.layerGroupId

        // find each child of the group, set its layer group id to the parent of the selected group
        children.forEach { child in
            if let layerNode = graph.getNodeViewModel(child) {
                layerNode.layerNode?.layerGroupId = newParentId
            }
        }

        // finally, delete layer group node itself (but not its children)
        graph.deleteNode(id: groupId, willDeleteLayerGroupChildren: false)

        // update legacy sidebar data
        graph.updateGraphData()
    }
}
