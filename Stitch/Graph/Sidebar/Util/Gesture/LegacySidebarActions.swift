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

struct SidebarListItemDragged: GraphEvent {

    let itemId: SidebarListItemId
    let translation: CGSize

    func handle(state: GraphState) {
        
         log("SidebarListItemDragged called: item \(itemId) ")
        
        var list = state.sidebarListState

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
    
 
    //
//    var draggedAlong: SidebarListItemIdSet = otherSelections
    log("onSidebarListItemDragged: otherSelections: \(otherSelections)")
    log("onSidebarListItemDragged: draggedAlong: \(draggedAlong)")

    // TODO: SEPT 24: raise z-index of ALL dragged/selected items
    item.zIndex = SIDEBAR_ITEM_MAX_Z_INDEX

    // First time this is called, we pass in ALL items
    let (newItems, newIndices, updatedAlreadyDragged, updatedDraggedAlong) = updatePositionsHelper(
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
    

    let updatedOriginalIndex = item.itemIndex(masterList.items)
    // update `item` again!
    item = masterList.items[updatedOriginalIndex]
    
    // should skip this for now?
    return setItemsInGroupOrTopLevel(
        item: item,
        masterList: masterList,
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

    item.zIndex = 0
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
