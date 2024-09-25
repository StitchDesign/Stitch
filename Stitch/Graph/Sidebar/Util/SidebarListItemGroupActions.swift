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
        let closedParent = retrieveItem(closedParentId.asItemId,
                                        self.sidebarListState.masterList.items)
        
        let descendants = Stitch.getDescendants(closedParent,
                                                self.sidebarListState.masterList.items)
        
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

struct SidebarListItemGroupOpened: GraphEventWithResponse {

    let openedParent: LayerNodeId
    
    func handle(state: GraphState) -> GraphResponse {

        state.sidebarListState.masterList = onSidebarListItemGroupOpened(
            openedId: openedParent.asItemId,
            state.sidebarListState.masterList)

//        state.sidebarExpandedItems.insert(openedParent)
        state.getNodeViewModel(openedParent.asNodeId)?.layerNode?.isExpandedInSidebar = true
        
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
        
        return .shouldPersist
    }
}


// When group opened:
// - move parent's children from ExcludedGroups to Items
// - wipe parent's entry in ExcludedGroups
// - move down (+y) any items below the now-open parent
func onSidebarListItemGroupOpened(openedId: SidebarListItemId,
                                  _ masterList: MasterList) -> MasterList {

    log("onSidebarListItemGroupOpened called")

    var masterList = masterList

    // important: remove this item from collapsedGroups,
    // so that we can unfurl its own children
    masterList.collapsedGroups.remove(openedId)

    let parentItem = retrieveItem(openedId, masterList.items)
    let parentIndex = parentItem.itemIndex(masterList.items)

    let originalCount = masterList.items.count

    let (updatedMaster, lastIndex) = unhideChildren(
        openedParent: openedId,
        parentIndex: parentIndex,
        parentY: parentItem.location.y,
        masterList)

    masterList = updatedMaster

    // count after adding hidden descendants back to `items`
    let updatedCount = masterList.items.count

    // how many items total we added by unhiding the parent's children
    let addedCount = updatedCount - originalCount

    let moveDownBy = addedCount * CUSTOM_LIST_ITEM_VIEW_HEIGHT

    // and move any items below this parent DOWN
    // ... but skip any children, since their positions' have already been updated
    masterList.items = adjustNonDescendantsBelow(
        lastIndex,
        adjustment: CGFloat(moveDownBy),
        masterList.items)

    return masterList
}

// When group closed:
// - remove parent's children from `items`
// - add removed children to ExcludedGroups dict
// - move up the position of items below the now-closed parent
@MainActor
func onSidebarListItemGroupClosed(closedId: SidebarListItemId,
                                  _ masterList: MasterList) -> MasterList {

    print("onSidebarListItemGroupClosed called")

    let closedParent = retrieveItem(closedId, masterList.items)

    var masterList = masterList

    if !hasOpenChildren(closedParent, masterList.items) {
        masterList.collapsedGroups.insert(closedId)
        masterList.excludedGroups.updateValue([], forKey: closedId)
        return masterList
    }

    let descendantsCount = getDescendants(
        closedParent,
        masterList.items).count

    let moveUpBy = descendantsCount * CUSTOM_LIST_ITEM_VIEW_HEIGHT

    // hide the children:
    // - populates ExcludedGroups
    // - removes now-hidden descendants from `items`
    masterList = hideChildren(closedParentId: closedId,
                              masterList)

    // and move any items below this parent upward
    masterList.items = adjustItemsBelow(
        // parent's own index should not have changed if we only
        // removed or changed items AFTER its index.
        closedParent.id,
        closedParent.itemIndex(masterList.items),
        adjustment: -CGFloat(moveUpBy),
        masterList.items)

    // add parent to collapsed group
    masterList.collapsedGroups.insert(closedId)

    return masterList
}
