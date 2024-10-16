//
//  _SidebarListItemGroupActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/9/24.
//

import Foundation
import StitchSchemaKit

extension ProjectSidebarObservable {
    func getSidebarExpandedItems() -> Set<ItemID> {
        self.items.filter {
            $0.isExpandedInSidebar ?? false
        }
        .map(\.id)
        .toSet
    }
    
    func applySidebarExpandedItems(_ expanded: Set<ItemID>) {
        self.items.forEach {
            if $0.isGroup {
                $0.isExpandedInSidebar = expanded.contains($0)
            } else {
                $0.isExpandedInSidebar = nil
            }
        }
    }
    
    // for non-edit-mode selections
    @MainActor
    func deselectDescendantsOfClosedGroup(_ closedParentId: Self.ItemID) {
        
        // Remove any non-edit-mode selected children; we don't want the 'selected sidebar layer' to be hidden
        guard let closedParent = retrieveItem(closedParentId,
                                              self.orderedEncodedData.getFlattenedList()) else {
            fatalErrorIfDebug("Could not retrieve item")
            return
        }
        
        let descendants = self.getDescendants(closedParent)
        
        for childen in descendants {
            self.selectionState.inspectorFocusedLayers.focused.remove(childen.id)
            self.selectionState.inspectorFocusedLayers.activelySelected.remove(childen.id)
        }
    }
    
    @MainActor
    func sidebarListItemGroupClosed(closedParentId: Self.ItemID) {

        var expanded = self.getSidebarExpandedItems()
        
        // Remove any non-edit-mode selected children; we don't want the 'selected sidebar layer' to be hidden
        self.deselectDescendantsOfClosedGroup(closedParentId)
                        
        self.onSidebarListItemGroupClosed(
            closedId: closedParentId.asItemId)
        
        //        // also need to remove id from sidebar's expandedSet
        //        expanded.remove(closedParent)
        
        // NOTEL Excluded-groups contains ALL collapsed groups; `masterList.collapsedGroups` only contains top-level collapsed groups?
        self.excludedGroups.keys.forEach {
            expanded.remove($0)
        }
                
        self.applySidebarExpandedItems(expanded)
        
//        _updateStateAfterListChange(
//            updatedList: state.sidebarListState,
//            expanded: state.getSidebarExpandedItems(),
//            graphState: state)
        
        self.graphDelegate?.encodeProjectInBackground()
    }
}

extension ProjectSidebarObservable {
    // When group opened:
    // - move parent's children from ExcludedGroups to Items
    // - wipe parent's entry in ExcludedGroups
    // - move down (+y) any items below the now-open parent
    @MainActor
    func sidebarListItemGroupOpened(openedId: Self.ItemID) {
        
        log("onSidebarListItemGroupOpened called")
        
        // important: remove this item from collapsedGroups,
        // so that we can unfurl its own children
        self.collapsedGroups.remove(openedId)
        
        guard let parentItem = retrieveItem(openedId, self.items) else {
            fatalErrorIfDebug("Could not retrieve item")
            return
        }
        
        let parentIndex = parentItem.itemIndex(self.items)
        let originalCount = self.items.count
        
        let lastIndex = self.unhideChildren(
            openedParent: openedId,
            parentIndex: parentIndex,
            parentY: parentItem.location.y)
        
        // count after adding hidden descendants back to `items`
        let updatedCount = self.items.count
        
        // how many items total we added by unhiding the parent's children
        let addedCount = updatedCount - originalCount
        
        let moveDownBy = addedCount * CUSTOM_LIST_ITEM_VIEW_HEIGHT
        
        // and move any items below this parent DOWN
        // ... but skip any children, since their positions' have already been updated
        self.adjustNonDescendantsBelow(
            lastIndex,
            adjustment: CGFloat(moveDownBy))
        
        // Trigger inherited class
        self.didGroupExpand(openedId)
        
        self.graphDelegate?.encodeProjectInBackground()
    }
    
    // When group closed:
    // - remove parent's children from `items`
    // - add removed children to ExcludedGroups dict
    // - move up the position of items below the now-closed parent
    @MainActor
    func onSidebarListItemGroupClosed(closedId: Self.ItemID) {
        
        print("onSidebarListItemGroupClosed called")
        
        guard let closedParent = retrieveItem(closedId, self.items) else {
            fatalErrorIfDebug("Could not retrieve item")
            return
        }
        
        if !hasOpenChildren(closedParent) {
            self.collapsedGroups.insert(closedId)
            self.excludedGroups.updateValue([], forKey: closedId)
            return
        }
        
        let descendantsCount = self.getDescendants(
            closedParent).count
        
        let moveUpBy = descendantsCount * CUSTOM_LIST_ITEM_VIEW_HEIGHT
        
        // hide the children:
        // - populates ExcludedGroups
        // - removes now-hidden descendants from `items`
        let _ = self.hideChildren(closedParentId: closedId)
        
        // and move any items below this parent upward
        self.adjustItemsBelow(
            // parent's own index should not have changed if we only
            // removed or changed items AFTER its index.
            closedParent.id,
            closedParent.itemIndex(self.items),
            adjustment: -CGFloat(moveUpBy))
        
        // add parent to collapsed group
        self.collapsedGroups.insert(closedId)
    }
}
