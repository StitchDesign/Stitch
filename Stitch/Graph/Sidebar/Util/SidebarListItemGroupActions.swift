//
//  _SidebarListItemGroupActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/9/24.
//

import Foundation
import StitchSchemaKit

extension GraphState {
    
    func getSidebarExpandedItems() -> LayerIdSet {
        self.layerNodes.values.filter {
            $0.layerNode?.isExpandedInSidebar ?? false
        }
        .map(\.id.asLayerNodeId)
        .toSet
    }
    
    func applySidebarExpandedItems(_ expanded: LayerIdSet) {
        self.layerNodes.values.forEach {
            if $0.isGroupLayer {
                $0.layerNode?.isExpandedInSidebar = expanded.contains($0.layerNodeId)
            } else {
                $0.layerNode?.isExpandedInSidebar = nil
            }
        }
    }
    
    // for non-edit-mode selections
    @MainActor
    func deselectDescendantsOfClosedGroup(_ closedParentId: LayerNodeId) {
        
        // Remove any non-edit-mode selected children; we don't want the 'selected sidebar layer' to be hidden
        guard let closedParent = retrieveItem(closedParentId.asItemId.id,
                                              self.orderedSidebarLayers.getFlattenedList()) else {
            fatalErrorIfDebug("Could not retrieve item")
            return
        }
        
        let descendants = Stitch.getDescendants(closedParent,
                                                self.orderedSidebarLayers.getFlattenedList())
        
        for childen in descendants {
            self.sidebarSelectionState.inspectorFocusedLayers.focused.remove(childen.id.asLayerNodeId)
            self.sidebarSelectionState.inspectorFocusedLayers.activelySelected.remove(childen.id.asLayerNodeId)
        }
    }
}

struct SidebarListItemGroupClosed: GraphEventWithResponse {

    let closedParentId: LayerNodeId
    
    func handle(state: GraphState) -> GraphResponse {

        var expanded = state.getSidebarExpandedItems()
        
        // Remove any non-edit-mode selected children; we don't want the 'selected sidebar layer' to be hidden
        state.deselectDescendantsOfClosedGroup(closedParentId)
                        
        state.sidebarListState.masterList = onSidebarListItemGroupClosed(
            closedId: closedParentId.asItemId,
            state.sidebarListState.masterList)
        
        //        // also need to remove id from sidebar's expandedSet
        //        expanded.remove(closedParent)
        
        // NOTEL Excluded-groups contains ALL collapsed groups; `masterList.collapsedGroups` only contains top-level collapsed groups?
        state.sidebarListState.masterList.excludedGroups.keys.forEach {
            expanded.remove($0.asLayerNodeId)
        }
                
        state.applySidebarExpandedItems(expanded)
        
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
        
        return .shouldPersist
    }
}

extension LayersSidebarViewModel {
    @MainActor
    func sidebarListItemGroupOpened(openedParent: SidebarListItemId) {

//        state.sidebarListState.masterList = onSidebarListItemGroupOpened(
//            openedId: openedParent.asItemId,
//            state.sidebarListState.masterList)

//        state.sidebarExpandedItems.insert(openedParent)
        self.graphDelegate?.getNodeViewModel(openedParent.asNodeId)?.layerNode?.isExpandedInSidebar = true
        
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
    func onSidebarListItemGroupOpened(openedId: Self.ItemID) {
        
        log("onSidebarListItemGroupOpened called")
        
        // important: remove this item from collapsedGroups,
        // so that we can unfurl its own children
        self.collapsedGroups.remove(openedId)
        
        guard let parentItem = retrieveItem(openedId, self.items) else {
            fatalErrorIfDebug("Could not retrieve item")
            return masterList
        }
        let parentIndex = parentItem.itemIndex(masterList.items)
        
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
        
        if !hasOpenChildren(closedParent, self.items) {
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
            closedParent.itemIndex(masterList.items),
            adjustment: -CGFloat(moveUpBy))
        
        // add parent to collapsed group
        self.collapsedGroups.insert(closedId)
    }
}
