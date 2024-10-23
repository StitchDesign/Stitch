//
//  _SidebarListItemGroupActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/9/24.
//

import Foundation
import StitchSchemaKit

extension ProjectSidebarObservable {    
    // for non-edit-mode selections
    @MainActor
    func deselectDescendantsOfClosedGroup(_ closedParent: Self.ItemViewModel) {
        
        // Remove any non-edit-mode selected children; we don't want the 'selected sidebar layer' to be hidden
        let descendants = closedParent.children?.flattenedItems ?? []
        
        for childen in descendants {
            self.selectionState.inspectorFocusedLayers.focused.remove(childen.id)
            self.selectionState.inspectorFocusedLayers.activelySelected.remove(childen.id)
        }
    }
    
    @MainActor
    func sidebarListItemGroupClosed(closedParent: Self.ItemViewModel) {

        closedParent.isExpandedInSidebar = false
        
        // Remove any non-edit-mode selected children; we don't want the 'selected sidebar layer' to be hidden
        self.deselectDescendantsOfClosedGroup(closedParent)
        
        self.items.updateSidebarIndices()
        
        self.persistSidebarChanges()
    }

    // When group opened:
    // - move parent's children from ExcludedGroups to Items
    // - wipe parent's entry in ExcludedGroups
    // - move down (+y) any items below the now-open parent
    @MainActor
    func sidebarListItemGroupOpened(parentItem: Self.ItemViewModel) {
        
        log("onSidebarListItemGroupOpened called")
        
        // Trigger inherited class
        parentItem.isExpandedInSidebar = true
        self.items.updateSidebarIndices()
        
        self.persistSidebarChanges()
    }
}
