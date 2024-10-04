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
    
    // All the focused layers minus the actively dragged item
    func getOtherSelections(draggedItem: SidebarListItemId) -> SidebarListItemIdSet {
        var otherDragged = self.sidebarSelectionState
            .inspectorFocusedLayers
            .focused.map(\.asItemId)
            .toSet
        
        otherDragged.remove(draggedItem)
        
        return otherDragged
    }
}

func getDraggedAlongHelper(item: SidebarListItemId,
                           allItems: SidebarListItems, // for retrieving children
                           acc: SidebarListItemIdSet) -> SidebarListItemIdSet {
    var acc = acc
    acc.insert(item)
    
    let children = allItems.filter { $0.parentId == item }
    children.forEach { child in
        let updatedAcc = getDraggedAlongHelper(item: child.id,
                                               allItems: allItems,
                                               acc: acc)
        acc = acc.union(updatedAcc)
    }
    
    return acc
}

func getDraggedAlong(_ draggedItem: SidebarListItem,
                     allItems: SidebarListItems,
                     acc: SidebarListItemIdSet,
                     selections: SidebarListItemIdSet) -> SidebarListItemIdSet {
    
    log("getDraggedAlong: draggedItem: \(draggedItem.layer) \(draggedItem.id)")
    
    var acc = acc
    
    let explicitlyDraggedItems: SidebarListItemIdSet = selections.union([draggedItem.id])
    
    explicitlyDraggedItems.forEach { explicitlyDraggedItem in
        let updatedAcc = getDraggedAlongHelper(item: explicitlyDraggedItem, allItems: allItems, acc: acc)
        acc = acc.union(updatedAcc)
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
        
        // log("SidebarListItemDragged called: item \(itemId) ")
        
//        var list = state.sidebarListState
        
        
        
        var itemId = itemId
        
        
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.haveDuplicated {
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.optionDragInProgress {
        if state.sidebarSelectionState.optionDragInProgress {
            // If we're currently doing an option+drag, then item needs to just be the top
            log("SidebarListItemDragged: had option drag and have already duplicated the layers")
            
            if let selectedItemWithSmallestIndex = findSetItemWithSmallestIndex(
             from: state.sidebarSelectionState.inspectorFocusedLayers.focused,
             in: state.orderedSidebarLayers.getFlattenedList()) {
                log("SidebarListItemDragged: had option drag, will use selectedItemWithSmallestIndex \(selectedItemWithSmallestIndex) as itemId")
                itemId = selectedItemWithSmallestIndex.asItemId
            }
        }
        
        let focusedLayers = state.sidebarSelectionState.inspectorFocusedLayers.focused
        
        // Dragging a layer not already selected = dragging just that layer and deselecting all the others
        if !focusedLayers.contains(itemId.asLayerNodeId) {
            state.sidebarSelectionState.resetEditModeSelections()
            let layerNodeId = itemId.asLayerNodeId
            state.sidebarSelectionState.inspectorFocusedLayers.focused = .init([layerNodeId])
            state.sidebarSelectionState.inspectorFocusedLayers.activelySelected = .init([layerNodeId])
            state.sidebarItemSelectedViaEditMode(layerNodeId,
                                                 isSidebarItemTapped: true)
            state.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = layerNodeId
        }
                
        
//        if state.keypressState.isOptionPressed && !state.sidebarSelectionState.haveDuplicated {
        if state.keypressState.isOptionPressed 
            && !state.sidebarSelectionState.haveDuplicated
            && !state.sidebarSelectionState.optionDragInProgress {
            log("SidebarListItemDragged: option held during drag; will duplicate layers")
            
            // duplicate the items
            // NOTE: will this be okay even though secretly async?, seems to work fine with option+node drag;
            // also, it aready updates the selected and focused sidebar layers etc.
            
            // But will the user's cursor still be on / under the original layer ?
            state.sidebarSelectedItemsDuplicatedViaEditMode()
            state.sidebarListState = state.sidebarListState
            state.sidebarSelectionState.haveDuplicated = true
            state.sidebarSelectionState.optionDragInProgress = true
            
            log("")
            // return ?
            // but will also need
            // NOTE: selection of the
            
            return
        }
        
        
        // If we have multiple layers already selected and are dragging one of these already-selected layers,
        // we create a "stack" (reorganization of selected layers) and treat the first layer in the stack as the user-dragged layer.
        
        // do we need this `else if` ?
//        else if focusedLayers.count > 1 {
        if focusedLayers.count > 1 {
            // log("SidebarListItemDragged: multiple selections; dragging an existing one")
            // Turn the master list into a "master list with a stack" first,
            if !state.sidebarSelectionState.madeStack,
                let item = state.sidebarListState.masterList.items.first(where: { $0.id == itemId }),
            
            let masterListWithStack = getStack(
                item,
                items: state.sidebarListState.masterList.items,
                selections: state.sidebarSelectionState.inspectorFocusedLayers.focused.asSidebarListItemIdSet) {
                
                // log("SidebarListItemDragged: masterListWithStack \(masterListWithStack.map(\.layer))")
                
                state.sidebarListState.masterList.items = masterListWithStack
                state.sidebarSelectionState.madeStack = true
            }
            
           if let selectedItemWithSmallestIndex = findSetItemWithSmallestIndex(
            from: state.sidebarSelectionState.inspectorFocusedLayers.focused,
            in: state.orderedSidebarLayers.getFlattenedList()),
            itemId != selectedItemWithSmallestIndex.asItemId {
               
               // If we had mutiple layers focused, the "dragged item" should be the top item
               // (Note: we'll also move all the potentially-disparate/island'd layers into a single stack; so we may want to do this AFTER the items are all stacked? or we're just concerned about the dragged-item, not its index per se?)
               itemId = selectedItemWithSmallestIndex.asItemId
               // log("SidebarListItemDragged item is now \(selectedItemWithSmallestIndex) ")
           }
        }

        guard let item = state.sidebarListState.masterList.items.first(where: { $0.id == itemId }) else {
            // if we couldn't find the item, it's been deleted
            log("SidebarListItemDragged: item \(itemId) was already deleted")
            return
        }
        
        let otherSelections = state.getOtherSelections(draggedItem: itemId)
        // log("SidebarListItemDragged: otherDragged \(otherSelections) ")

        let (result, draggedAlong) = onSidebarListItemDragged(
            item, // this dragged item
            translation, // drag data
            // ALL items
            state.sidebarListState.masterList,
            otherSelections: otherSelections)

        state.sidebarListState.current = result.beingDragged
        state.sidebarListState.masterList = result.masterList
        state.sidebarListState.proposedGroup = result.proposed
        state.sidebarListState.cursorDrag = result.cursorDrag
        
        
        // JUST USED FOR UI PURPOSES, color changes etc.
        let implicitlyDragged = getImplicitlyDragged(
            items: state.sidebarListState.masterList.items,
            draggedAlong: draggedAlong,
            selections: state.sidebarSelectionState.inspectorFocusedLayers.focused.asSidebarListItemIdSet)
        state.sidebarSelectionState.implicitlyDragged = implicitlyDragged
                        
        // Need to update the preview window then
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
        
        // Recalculate the ordered-preview-layers
        state.updateOrderedPreviewLayers()
    }
}

let SIDEBAR_ITEM_MAX_Z_INDEX: ZIndex = 999


@MainActor
func onSidebarListItemDragged(_ item: SidebarListItem, // assumes we've already
                              _ translation: CGSize,
                              _ masterList: MasterList,
                              otherSelections: SidebarListItemIdSet) -> (SidebarListItemDraggedResult, SidebarListItemIdSet) {

    // log("onSidebarListItemDragged called: item.id: \(item.id)")
    
    var item = item
    var masterList = masterList
    var cursorDrag = SidebarCursorHorizontalDrag.fromItem(item)
    let originalItemIndex = masterList.items.firstIndex { $0.id == item.id }!
    
    var alreadyDragged = SidebarListItemIdSet()
    var draggedAlong = SidebarListItemIdSet()
     
    // log("onSidebarListItemDragged: otherSelections: \(otherSelections)")
    // log("onSidebarListItemDragged: draggedAlong: \(draggedAlong)")

    // TODO: remove this property, and use an `isBeingDragged` check in the UI instead?
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

        var itemId = itemId
        
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.haveDuplicated {
        if state.sidebarSelectionState.optionDragInProgress {
            // If we're currently doing an option+drag, then item needs to just be the top
            log("SidebarListItemDragged: had option drag and have already duplicated the layers")
            
            if let selectedItemWithSmallestIndex = findSetItemWithSmallestIndex(
             from: state.sidebarSelectionState.inspectorFocusedLayers.focused,
             in: state.orderedSidebarLayers.getFlattenedList()) {
                log("SidebarListItemDragged: had option drag, will use selectedItemWithSmallestIndex \(selectedItemWithSmallestIndex) as itemId")
                itemId = selectedItemWithSmallestIndex.asItemId
            }
        }
        
        
        let item = state.sidebarListState.masterList.items.first { $0.id == itemId }
        guard let item = item else {
            // if we couldn't find the item, it's been deleted
             log("SidebarListItemDragEnded: item \(itemId) was already deleted")
            return .noChange
        }

        // if no `current`, then we were just swiping?
        if let current = state.sidebarListState.current {
            state.sidebarListState.masterList.items = onSidebarListItemDragEnded(
                item,
                state.sidebarListState.masterList.items,
                otherSelections: state.getOtherSelections(draggedItem: itemId),
                // MUST have a `current`
                // NO! ... this can be nil now eg when we call our onDragEnded logic via swipe
                draggedAlong: current.draggedAlong,
                proposed: state.sidebarListState.proposedGroup)
        } else {
            log("SidebarListItemDragEnded: had no current, so will not do the full onDragEnded call")
        }

        // also reset: the potentially highlighted group,
        state.sidebarListState.proposedGroup = nil
        // the current dragging item,
        state.sidebarListState.current = nil
        // and the current x-drag tracking
        state.sidebarListState.cursorDrag = nil
                
        state.sidebarSelectionState.madeStack = false
        state.sidebarSelectionState.haveDuplicated = false
        state.sidebarSelectionState.optionDragInProgress = false
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

    log("onSidebarListItemDragEnded called")

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

    let allDragged: SidebarListItemIds = [item.id] + Array(draggedAlong) + otherSelections

    // update both the X and Y in the previousLocation of the items that were moved;
    // ie `item` AND every id in `draggedAlong`
    for draggedId in allDragged {
        guard var draggedItem = retrieveItem(draggedId, items) else {
            fatalErrorIfDebug("Could not retrieve item")
            continue
        }
        draggedItem.previousLocation = draggedItem.location
        items = updateSidebarListItem(draggedItem, items)
    }

    // reset the z-indices
    items = updateZIndices(items, zIndex: 0)

    return items
}
