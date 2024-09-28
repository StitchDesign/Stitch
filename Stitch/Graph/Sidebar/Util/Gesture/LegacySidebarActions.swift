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
////
//func getMasterListWithStack(_ draggedItem: SidebarListItem,
//                            items: SidebarListItems,
//                            // i.e. focused selections
//                            selections: LayerIdSet) -> SidebarListItems? {
//    
//    let draggedAlong = getDraggedAlong(draggedItem,
//                                       allItems: items,
//                                       acc: .init())
//    
//    
//    
//    guard let draggedItemIndex = items.firstIndex(where: { $0.id == draggedItem.id }) else {
//        return nil
//    }
//    
//    let itemsAboveStart = items.filter { item in
//        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
//            return itemIndex < draggedItemIndex
//        }
//        return false
//    }
//    
//    let selectedItemsAbove = itemsAboveStart.filter {
//        selections.contains($0.id.asLayerNodeId) || draggedAlong.contains($0.id)
//    }
//    let nonSelectedItemsAbove = itemsAboveStart.filter {
//        !selections.contains($0.id.asLayerNodeId) && !draggedAlong.contains($0.id)
//    }
//    
//    let itemsBelowStart = items.filter { item in
//        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
//            return itemIndex > draggedItemIndex
//        }
//        return false
//    }
//        
//    let explicitlyDraggedItemsBelow = itemsBelowStart.filter { selections.contains($0.id.asLayerNodeId) }
//    
//    // Implicitly dragged = not selected, but dragged along
//    let implicitlyDraggedItemsBelow = itemsBelowStart.filter {
//        draggedAlong.contains($0.id) && !selections.contains($0.id.asLayerNodeId)
//    }
//    
//    let nonSelectedItemsBelow = itemsBelowStart.filter {
//        !selections.contains($0.id.asLayerNodeId) && !draggedAlong.contains($0.id)
//    }
//    
//    // The reordered masterList
//    let rearrangedMasterList = nonSelectedItemsAbove + selectedItemsAbove + [draggedItem] + nonSelectedItemsBelow
//    
//    // Use the newly-reordered masterList's indices to update each master list item's y position
//    let _rearrangedMasterList = setYPositionByIndices(
//        originalItemId: draggedItem.id,
//        rearrangedMasterList,
//        // treat as drag ended so that we update previousLocation etc.
//        isDragEnded: true)
//    
//    // Wipe the identation levels and parentIds of any directly-selected items (part of taking them out of their group)
//    let _indentationsWiped = wipeIndentationLevelsOfSelectedItems(
//        items: _rearrangedMasterList,
//        selections: selections)
//    
//    return _indentationsWiped
//}


// Recursively crawls to find all items below that would be dragged, given that we're dragging some other item
// Ideally

/*
 Simplify this?
 Any item that is selected is explicitly-dragged;
 and any item that has an explicitly-dragged parent is thereby implicitly-dragged;

 ah but if you have e.g. a case where an item's parent is itself implicitly dragged...
 */

func getDraggedAlong(_ draggedItem: SidebarListItem,
                     allItems: SidebarListItems,
                     acc: SidebarListItemIdSet,
                     selections: SidebarListItemIdSet) -> SidebarListItemIdSet {
    log("getDraggedAlong: draggedItem: \(draggedItem.layer) \(draggedItem.id)")
    var acc = acc
    allItems.forEach { item in
        log("getDraggedAlong: on item: \(item.layer) \(item.id)")
        let isNotDraggedItem = item.id != draggedItem.id
        let isChildOfDraggedParent = (item.parentId.map({ $0 == draggedItem.id }) ?? false)
        let isOtherDragged = item.isSelected(selections)
        let isNotAlreadyDragged = !acc.contains(item.id)
        // STILL doesn't work for purple ? // But purple is the child of dragged group E5
        log("getDraggedAlong: isNotDraggedItem: \(isNotDraggedItem)")
        log("getDraggedAlong: isChildOfDraggedParent: \(isChildOfDraggedParent)")
        log("getDraggedAlong: isOtherDragged: \(isOtherDragged)")
        log("getDraggedAlong: isNotAlreadyDragged: \(isNotAlreadyDragged)")
        
        
        if isNotDraggedItem && isNotAlreadyDragged && (isChildOfDraggedParent || isOtherDragged) { // parentId test is not good?
            log("getDraggedAlong: will add item: \(item.layer) \(item.id) to acc and recur")
            acc.insert(item.id)
            
            let newDraggedAlong = getDraggedAlong(item,
                                                  allItems: allItems,
                                                  acc: acc,
                                                  selections: selections)
            acc = acc.union(newDraggedAlong)
        } else {
            log("getDraggedAlong: will NOT add item: \(item.layer) \(item.id) to acc, will NOT recur")
        }
    }
    
    return acc
}

// Note: call this AFTER we've dragged and have a big list of all the 'dragged along' items
func getImplicitlyDragged(items: SidebarListItems,
                          draggedAlong: SidebarListItemIdSet,
                          selections: SidebarListItemIdSet) -> SidebarListItemIdSet {
    
    items.reduce(into: SidebarListItemIdSet()) { partialResult, item in
        // if the item was NOT selected, yet was dragged along,
        // then it is "implicitly" selected
        if !selections.contains(item.id),
           draggedAlong.contains(item.id) {
            partialResult.insert(item.id)
        }
    }
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
               
//               let masterListWithStack = getMasterListWithStack(
//                item,
//                items: list.masterList.items,
//                selections: state.sidebarSelectionState.inspectorFocusedLayers.focused)
            
            let masterListWithStack = getStack(
                item,
                items: list.masterList.items,
                selections: state.sidebarSelectionState.inspectorFocusedLayers.focused.asSidebarListItemIdSet) {
                
//                log("SidebarListItemDragged: had a master list with stack \(masterListWithStack.map(\.id))")
                log("SidebarListItemDragged: masterListWithStack \(masterListWithStack.map(\.layer))")
                
                list.masterList.items = masterListWithStack
                state.sidebarSelectionState.madeStack = true
                
                // TODO: SEPT 24: do this for single selection dragging of a group too ? might be nice touch
                // implicitly dragged = not directly dragged but one of its ancestor is dragged
//                state.sidebarSelectionState.implicitlyDragged
                
                // TODO: should we exit early here then?
//                return // added
            }
            
           if let selectedItemWithSmallestIndex = findSetItemWithSmallestIndex(
            from: state.sidebarSelectionState.inspectorFocusedLayers.focused,
            in: state.orderedSidebarLayers.getFlattenedList()),
            itemId != selectedItemWithSmallestIndex.asItemId {
               
               // If we had mutiple layers focused, the "dragged item" should be the top item
               // (Note: we'll also move all the potentially-disparate/island'd layers into a single stack; so we may want to do this AFTER the items are all stacked? or we're just concerned about the dragged-item, not its index per se?)
               itemId = selectedItemWithSmallestIndex.asItemId
               log("SidebarListItemDragged item is now \(selectedItemWithSmallestIndex) ")
           }
        }

        guard let item = list.masterList.items.first(where: { $0.id == itemId }) else {
            // if we couldn't find the item, it's been deleted
            log("SidebarListItemDragged: item \(itemId) was already deleted")
            return
        }
        
        let otherDragged = state.getOtherDraggedItems(draggedItem: itemId)
        log("SidebarListItemDragged: otherDragged \(otherDragged) ")

        let (result, draggedAlong) = onSidebarListItemDragged(
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
        
        // JUST USED FOR UI PURPOSES, color changes etc.
        let implicitlyDragged = getImplicitlyDragged(
            items: list.masterList.items,
            draggedAlong: draggedAlong,
            selections: state.sidebarSelectionState.inspectorFocusedLayers.focused.asSidebarListItemIdSet)
        state.sidebarSelectionState.implicitlyDragged = implicitlyDragged
                        
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
                              otherSelections: SidebarListItemIdSet) -> (SidebarListItemDraggedResult, SidebarListItemIdSet) {

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
    let result = setItemsInGroupOrTopLevel(
        item: item,
        masterList: masterList,
        otherSelections: otherSelections,
        draggedAlong: draggedAlong,
        cursorDrag: cursorDrag)
    
    return (result, draggedAlong)
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
        state.sidebarSelectionState.implicitlyDragged = .init()
    
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
