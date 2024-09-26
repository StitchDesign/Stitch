//
//  LegacySidebarActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemLongPressed: GraphEvent {

    let id: SidebarListItemId

    func handle(state: GraphState) {
    
        // log("SidebarListItemLongPressed called: id: \(id)")

        state.sidebarListState.current = SidebarDraggedItem(
            current: id,
            // can be empty just because
            // we're first starting the drag
            draggedAlong: SidebarListItemIdSet())
    }
}

import Foundation

// Function to find the set item whose index in the list is the smallest
func findSetItemWithSmallestIndex(from set: LayerIdSet,
                                  in list: [ListItem]) -> LayerNodeId? {
    var smallestIndex: Int? = nil
    var smallestItem: LayerNodeId? = nil

    // Iterate through each item in the set
    for item in set {
        if let index = list.firstIndex(where: { $0.id == item.id }) {
            // If it's the first item or if its index is smaller than the current smallest, update it
            if smallestIndex == nil || index < smallestIndex! {
                smallestIndex = index
                smallestItem = item
            }
        }
    }

    // Return the item with the smallest index, or nil if no items from the set were found in the list
    return smallestItem
}

extension GraphState {
    func getOtherDraggedItems(draggedItem: SidebarListItemId) -> SidebarListItemIdSet {
        
        // All the focused layers minus the actively dragged item
        var otherDragged = self.sidebarSelectionState
            .inspectorFocusedLayers
            .focused.map(\.asItemId)
            .toSet
        
        otherDragged.remove(draggedItem)
        
        return otherDragged
    }
}

func getMasterListWithStack(_ draggedItem: SidebarListItem,
                            items: SidebarListItems,
                            // i.e. focused selections
                            selections: LayerIdSet) -> SidebarListItems? {
    
    guard let draggedItemIndex = items.firstIndex(where: { $0.id == draggedItem.id }) else {
        return nil
    }
    
    let itemsAboveStart = items.filter { item in
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
            return itemIndex < draggedItemIndex
        }
        return false
    }
    
    let selectedItemsAbove = itemsAboveStart.filter { selections.contains($0.id.asLayerNodeId) }
    let nonSelectedItemsAbove = itemsAboveStart.filter { !selections.contains($0.id.asLayerNodeId) }
    
    let itemsBelowStart = items.filter { item in
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
            return itemIndex > draggedItemIndex
        }
        return false
    }
    
    let selectedItemsBelow = itemsBelowStart.filter { selections.contains($0.id.asLayerNodeId) }
    let nonSelectedItemsBelow = itemsBelowStart.filter { !selections.contains($0.id.asLayerNodeId) }
        
    
    // The reordered masterList
    let rearrangedMasterList = nonSelectedItemsAbove + selectedItemsAbove + [draggedItem] + selectedItemsBelow + nonSelectedItemsBelow
    
    // Use the newly-reordered masterList's indices to update each master list item's y position
    let _rearrangedMasterList = setYPositionByIndices(
        originalItemId: draggedItem.id,
        rearrangedMasterList,
        // treat as drag ended so that we update previousLocation etc.
        isDragEnded: true)
    
    // Wipe the identation levels of any directly-selected items (part of taking them out of their group)
    let _identationsWiped = wipeIndentationLevelsOfSelectedItems(
        items: _rearrangedMasterList,
        selections: selections)
    
    // Directly-selected items also need to be taken out of any parents' lists
    let _selectedChildrenRemovedFromParents = removeSelectedItemsFromParents(
        items: _identationsWiped,
        selections: selections)
    
    return _selectedChildrenRemovedFromParents
}

struct SidebarListItemDragged: GraphEvent {

    let itemId: SidebarListItemId
    let translation: CGSize

    func handle(state: GraphState) {
        
         log("SidebarListItemDragged called: item \(itemId) ")
        
        var list = state.sidebarListState
        
        var itemId = itemId
        
        if state.sidebarSelectionState.inspectorFocusedLayers.focused.count > 1 {
           
            // Turn the master list into a "master list with a stack" first,
            
            if !state.sidebarSelectionState.madeStack,
                let item = list.masterList.items.first(where: { $0.id == itemId }),
               let masterListWithStack = getMasterListWithStack(
                item,
                items: list.masterList.items,
                selections: state.sidebarSelectionState.inspectorFocusedLayers.focused) {
                
//                log("SidebarListItemDragged: had a master list with stack \(masterListWithStack.map(\.id))")
                log("SidebarListItemDragged: masterListWithStack \(masterListWithStack)")
                
                list.masterList.items = masterListWithStack
                state.sidebarSelectionState.madeStack = true
                
                // TODO: should we exit early here then?
//                return // added
            
//                // Use the newly-reordered masterList's indices to update each master list item's y position
//                let _masterListWithStack = setYPositionByIndices(
//                    originalItemId: itemId,
//                    masterListWithStack,
//                    // treat as drag ended so that we update previousLocation etc.
//                    isDragEnded: true)
//                
//                log("SidebarListItemDragged: _masterListWithStack: \(_masterListWithStack)")
//
//                list.masterList.items = _masterListWithStack
//                list.masterList.items = masterListWithStack
//                state.sidebarSelectionState.madeStack = true
            }
            
           if let selectedItemWithSmallestIndex = findSetItemWithSmallestIndex(
            from: state.sidebarSelectionState.inspectorFocusedLayers.focused,
            in: state.orderedSidebarLayers.getFlattenedList()) {
               
               // If we had mutiple layers focused, the "dragged item" should be the top item
               // (Note: we'll also move all the potentially-disparate/island'd layers into a single stack; so we may want to do this AFTER the items are all stacked? or we're just concerned about the dragged-item, not its index per se?)
               itemId = selectedItemWithSmallestIndex.asItemId
               log("SidebarListItemDragged item is now \(itemId) ")
           }
        }

        guard let item = list.masterList.items.first(where: { $0.id == itemId }) else {
            // if we couldn't find the item, it's been deleted
            log("SidebarListItemDragged: item \(itemId) was already deleted")
            return
        }
        
        let otherDragged = state.getOtherDraggedItems(draggedItem: itemId)
        log("SidebarListItemDragged: otherDragged \(otherDragged) ")

        let result = onSidebarListItemDragged(
            item, // this dragged item
            translation, // drag data
            // ALL items
            list.masterList,
            otherSelections: otherDragged)

        list.current = result.beingDragged
        list.masterList = result.masterList
        list.proposedGroup = result.proposed
        list.cursorDrag = result.cursorDrag
        
        state.sidebarListState = list
                        
        // Need to update the preview window then
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
        
        
        // TODO: SEPT 24: DRAGGING MULTIPLE LAYERS DOES NOT RESET SELECTION STATUS
        
        // Update selection state
//        state.sidebarSelectionState = .init()
//        state.sidebarSelectionState.resetEditModeSelections()
//        
//        let layerNodeId = item.id.asLayerNodeId
//        
//        state.sidebarSelectionState.inspectorFocusedLayers.focused = .init([layerNodeId])
//        
//        state.sidebarSelectionState.inspectorFocusedLayers.activelySelected = .init([layerNodeId])
//        
//        state.sidebarItemSelectedViaEditMode(layerNodeId,
//                                             isSidebarItemTapped: true)
        
//        state.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = layerNodeId
        
        // Recalculate the ordered-preview-layers
        state.documentDelegate?.updateOrderedPreviewLayers()
    }
}

let SIDEBAR_ITEM_MAX_Z_INDEX: ZIndex = 999


@MainActor
func onSidebarListItemDragged(_ item: SidebarListItem, // assumes we've already
                              _ translation: CGSize,
                              _ masterList: MasterList,
                              otherSelections: SidebarListItemIdSet) -> SidebarListItemDraggedResult {

    log("onSidebarListItemDragged called: item.id: \(item.id)")
    
    var item = item
    var masterList = masterList
    var cursorDrag = SidebarCursorHorizontalDrag.fromItem(item)
    let originalItemIndex = masterList.items.firstIndex { $0.id == item.id }!
    
    var alreadyDragged = SidebarListItemIdSet()
    var draggedAlong = SidebarListItemIdSet()
     
    //    var draggedAlong: SidebarListItemIdSet = otherSelections
    log("onSidebarListItemDragged: otherSelections: \(otherSelections)")
    log("onSidebarListItemDragged: draggedAlong: \(draggedAlong)")

    // TODO: SEPT 24: raise z-index of ALL dragged/selected items
    item.zIndex = SIDEBAR_ITEM_MAX_Z_INDEX

    // First time this is called, we pass in ALL items
    let (newItems, 
         newIndices,
         updatedAlreadyDragged,
         updatedDraggedAlong) = updatePositionsHelper(
            item,
            masterList.items,
            [],
            translation,
            otherSelections: otherSelections,
            alreadyDragged: alreadyDragged,
            draggedAlong: draggedAlong)

    // limit this from going negative?
    cursorDrag.x = cursorDrag.previousX + translation.width

    masterList.items = newItems
    item = masterList.items[originalItemIndex] // update the `item` too!
    alreadyDragged = alreadyDragged.union(updatedAlreadyDragged)
    draggedAlong = draggedAlong.union(updatedDraggedAlong)
    
    let calculatedIndex = calculateNewIndexOnDrag(
        item: item,
        items: masterList.items,
        otherSelections: otherSelections,
        draggedAlong: draggedAlong,
        movingDown: translation.height > 0,
        originalItemIndex: originalItemIndex,
        movedIndices: newIndices)

    masterList.items = maybeMoveIndices(
        originalItemId: item.id,
        masterList.items,
        indicesMoved: newIndices,
        to: calculatedIndex,
        originalIndex: originalItemIndex)
    

    // i.e. get the index of this dragged-item, given the updated masterList's items
    let updatedOriginalIndex = item.itemIndex(masterList.items)
    // update `item` again!
    item = masterList.items[updatedOriginalIndex]
    
    // should skip this for now?
    return setItemsInGroupOrTopLevel(
        item: item,
        masterList: masterList,
        otherSelections: otherSelections,
        draggedAlong: draggedAlong,
        cursorDrag: cursorDrag)
}

struct SidebarListItemDraggedResult {
    let masterList: MasterList
    let proposed: ProposedGroup?
    let beingDragged: SidebarDraggedItem
    let cursorDrag: SidebarCursorHorizontalDrag
}

struct SidebarListItemDragEnded: GraphEventWithResponse {

    let itemId: SidebarListItemId
    
    func handle(state: GraphState) -> GraphResponse {
    
        log("SidebarListItemDragEnded called: itemId: \(itemId)")

        var list = state.sidebarListState
        let item = list.masterList.items.first { $0.id == itemId }
        guard let item = item else {
            // if we couldn't find the item, it's been deleted
             log("SidebarListItemDragEnded: item \(itemId) was already deleted")
//            return .noChange
            return .noChange
        }

        // if no `current`, then we were just swiping?
        if let current = list.current {
            list.masterList.items = onSidebarListItemDragEnded(
                item,
                list.masterList.items, 
                otherSelections: state.getOtherDraggedItems(draggedItem: itemId),
                // MUST have a `current`
                // NO! ... this can be nil now eg when we call our onDragEnded logic via swipe
                draggedAlong: current.draggedAlong,
                proposed: list.proposedGroup)
        } else {
            log("SidebarListItemDragEnded: had no current, so will not do the full onDragEnded call")
        }

        // also reset: the potentially highlighted group,
        list.proposedGroup = nil
        // the current dragging item,
        list.current = nil
        // and the current x-drag tracking
        list.cursorDrag = nil
        
        state.sidebarListState = list
        
        // TODO: SEPT 24: avoid this?
        state.sidebarSelectionState.madeStack = false
    
        return .persistenceResponse
    }
}


@MainActor
func onSidebarListItemDragEnded(_ item: SidebarListItem,
                                _ items: SidebarListItems,
                                otherSelections: SidebarListItemIdSet,
                                draggedAlong: SidebarListItemIdSet,
                                proposed: ProposedGroup?) -> SidebarListItems {

        print("onSidebarListItemDragEnded called")

    var items = items
    var item = item

    item.zIndex = 0 // is this even used still?
    let index = item.itemIndex(items)
    items[index] = item

    // finalizes items' positions by index;
    // also updates items' previousPositions.
    items = setYPositionByIndices(
        originalItemId: item.id,
        items,
        isDragEnded: true)

//    let allDragged: SidebarListItemIds = [item.id] + Array(draggedAlong)
    let allDragged: SidebarListItemIds = [item.id] + Array(draggedAlong) + otherSelections

    // update both the X and Y in the previousLocation of the items that were moved;
    // ie `item` AND every id in `draggedAlong`
    for draggedId in allDragged {
        var draggedItem = retrieveItem(draggedId, items)
        draggedItem.previousLocation = draggedItem.location
        items = updateSidebarListItem(draggedItem, items)
    }

    // reset the z-indices
    items = updateZIndices(items, zIndex: 0)

    return items
}
