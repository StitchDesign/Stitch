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
        
        guard let graph = self.graphDelegate,
              let group = primarilySelectedGroups.first,
              let item = self.items.get(group) else {
            // Expected group here
            fatalErrorIfDebug()
            return
        }
        
        let children = item.children ?? []
        
        // Update sidebar self
        let newList = self.items.ungroup(selectedGroupId: group)
        self.items = newList
        
        // reset selection-state
        self.selectionState.resetEditModeSelections()
        
        self.sidebarGroupUncreatedViaEditMode(groupId: group,
                                              children: children.map(\.id))

        graph.encodeProjectInBackground()
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

        // Delete layer group node itself (but not its children)
        // Note: the uncreated-group's children's new parent (nil or the next closest ancestor) is handled automatically?
        graph.deleteNode(id: groupId, willDeleteLayerGroupChildren: false)

        // update legacy sidebar data
        // TODO: APRIL 11: should not be necessary anymore? since causes a persistence change
        guard let document = graph.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        graph.updateGraphData(document)
    }
}
