//
//  LegacySidebarActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let SIDEBAR_ITEM_MAX_Z_INDEX: ZIndex = 999

extension ProjectSidebarObservable {
    @MainActor
    func sidebarListItemLongPressed(id: Self.ItemID) {
        self.currentItemDragged = SidebarDraggedItem(
            current: id,
            // can be empty just because
            // we're first starting the drag
            draggedAlong: .init())
    }

    // Function to find the set item whose index in the list is the smallest
    static func findSetItemWithSmallestIndex(from set: Set<Self.ItemID>,
                                             in list: [Self.EncodedItemData]) -> Self.ItemID? {
        var smallestIndex: Int? = nil
        var smallestItem: Self.ItemID? = nil
        
        // Iterate through each item in the set
        for item in set {
            if let index = list.firstIndex(where: { $0.id == item }) {
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
    
    // All the focused layers minus the actively dragged item
    func getOtherSelections(draggedItem: Self.ItemID) -> Set<Self.ItemID> {
        var otherDragged = self.selectionState
            .inspectorFocusedLayers
            .focused
            .toSet
        
        otherDragged.remove(draggedItem)
        
        return otherDragged
    }
    
    func getDraggedAlongHelper(item: Self.ItemID,
                               acc: Set<Self.ItemID>) -> Set<Self.ItemID> {
        var acc = acc
        acc.insert(item)
        
        let children = self.items.filter { $0.parentId == item }
        children.forEach { child in
            let updatedAcc = getDraggedAlongHelper(item: child.id,
                                                   acc: acc)
            acc = acc.union(updatedAcc)
        }
        
        return acc
    }
    
    func getDraggedAlong(_ draggedItem: Self.ItemViewModel,
                         acc: Set<Self.ItemID>,
                         selections: Set<Self.ItemID>) -> Set<Self.ItemID> {
        var acc = acc
        
        let explicitlyDraggedItems = selections.union([draggedItem.id])
        
        explicitlyDraggedItems.forEach { explicitlyDraggedItem in
            let updatedAcc = self
                .getDraggedAlongHelper(item: explicitlyDraggedItem,
                                       acc: acc)
            acc = acc.union(updatedAcc)
        }
        
        return acc
    }

    // Note: call this AFTER we've dragged and have a big list of all the 'dragged along' items
    func getImplicitlyDragged(draggedAlong: Set<ItemID>,
                              selections: Set<ItemID>) -> Set<ItemID> {
        
        self.items.reduce(into: Set<ItemID>()) { partialResult, item in
            // if the item was NOT selected, yet was dragged along,
            // then it is "implicitly" selected
            if !selections.contains(item.id),
               draggedAlong.contains(item.id) {
                partialResult.insert(item.id)
            }
        }
    }
    
    @MainActor
    func sidebarListItemDragged(itemId: Self.ItemID,
                                translation: CGSize) {
        
        // log("SidebarListItemDragged called: item \(itemId) ")
        guard let graph = self.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let state = self
        var itemId = itemId
        
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.haveDuplicated {
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.optionDragInProgress {
        if state.selectionState.optionDragInProgress {
            // If we're currently doing an option+drag, then item needs to just be the top
            log("SidebarListItemDragged: had option drag and have already duplicated the layers")
            
            if let selectedItemWithSmallestIndex = Self.findSetItemWithSmallestIndex(
                from: state.inspectorFocusedLayers.focused,
                in: state.orderedEncodedData.flattenedItems) {
                log("SidebarListItemDragged: had option drag, will use selectedItemWithSmallestIndex \(selectedItemWithSmallestIndex) as itemId")
                itemId = selectedItemWithSmallestIndex
            }
        }
        
        let focusedLayers = state.inspectorFocusedLayers.focused
        
        // Dragging a layer not already selected = dragging just that layer and deselecting all the others
        if !focusedLayers.contains(itemId) {
            state.selectionState.resetEditModeSelections()
            state.selectionState.inspectorFocusedLayers.focused = .init([itemId])
            state.selectionState.inspectorFocusedLayers.activelySelected = .init([itemId])
            state.sidebarItemSelectedViaEditMode(itemId,
                                                 isSidebarItemTapped: true)
            state.selectionState.inspectorFocusedLayers.lastFocusedLayer = itemId
        }
                
        
//        if state.keypressState.isOptionPressed && !state.sidebarSelectionState.haveDuplicated {
        if graph.keypressState.isOptionPressed
            && !state.selectionState.haveDuplicated
            && !state.selectionState.optionDragInProgress {
            log("SidebarListItemDragged: option held during drag; will duplicate layers")
            
            // duplicate the items
            // NOTE: will this be okay even though secretly async?, seems to work fine with option+node drag;
            // also, it aready updates the selected and focused sidebar layers etc.
            
            // But will the user's cursor still be on / under the original layer ?
            state.graphDelegate?.sidebarSelectedItemsDuplicatedViaEditMode()
//            state.sidebarListState = state.sidebarListState
            state.selectionState.haveDuplicated = true
            state.selectionState.optionDragInProgress = true
            
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
            if !state.selectionState.madeStack,
                let item = self.items.first(where: { $0.id == itemId }),
            
                self.updateStackOnDrag(
                    item,
                    selections: state.selectionState.inspectorFocusedLayers.focused) {
                
                state.selectionState.madeStack = true
            }
            
            if let selectedItemWithSmallestIndex = Self.findSetItemWithSmallestIndex(
                from: state.selectionState.inspectorFocusedLayers.focused,
                in: state.orderedSidebarLayers.flattenedItems),
               itemId != selectedItemWithSmallestIndex {
               
               // If we had mutiple layers focused, the "dragged item" should be the top item
               // (Note: we'll also move all the potentially-disparate/island'd layers into a single stack; so we may want to do this AFTER the items are all stacked? or we're just concerned about the dragged-item, not its index per se?)
               itemId = selectedItemWithSmallestIndex
               // log("SidebarListItemDragged item is now \(selectedItemWithSmallestIndex) ")
           }
        }

        guard let item = state.items.first(where: { $0.id == itemId }) else {
            // if we couldn't find the item, it's been deleted
            log("SidebarListItemDragged: item \(itemId) was already deleted")
            return
        }
        
        let otherSelections = state.getOtherSelections(draggedItem: itemId)
        // log("SidebarListItemDragged: otherDragged \(otherSelections) ")

        let draggedAlong = self.onSidebarListItemDragged(
            item, // this dragged item
            translation, // drag data
            // ALL items
            otherSelections: otherSelections)
        
        // JUST USED FOR UI PURPOSES, color changes etc.
        let implicitlyDragged = self.getImplicitlyDragged(
            draggedAlong: draggedAlong,
            selections: state.selectionState.inspectorFocusedLayers.focused)
        state.implicitlyDragged = implicitlyDragged
                        
        // Need to update the preview window then
//        _updateStateAfterListChange(
//            updatedList: state.sidebarListState,
//            expanded: state.getSidebarExpandedItems(),
//            graphState: state)
        
        // Recalculate the ordered-preview-layers
        state.graphDelegate?.updateOrderedPreviewLayers()
    }
    
    @MainActor
    func onSidebarListItemDragged(_ item: Self.ItemViewModel, // assumes we've already
                                  _ translation: CGSize,
                                  otherSelections: Set<ItemID>) -> Set<ItemID> {
        
        // log("onSidebarListItemDragged called: item.id: \(item.id)")
        
        var item = item
        var cursorDrag = Self.HorizontalDrag.fromItem(item)
        let originalItemIndex = self.items.firstIndex { $0.id == item.id }!
        
        var alreadyDragged = Set<ItemID>()
        var draggedAlong = Set<ItemID>()
        
        // log("onSidebarListItemDragged: otherSelections: \(otherSelections)")
        // log("onSidebarListItemDragged: draggedAlong: \(draggedAlong)")
        
        // TODO: remove this property, and use an `isBeingDragged` check in the UI instead?
        item.zIndex = SIDEBAR_ITEM_MAX_Z_INDEX
        
        // First time this is called, we pass in ALL items
        let (newIndices,
             updatedAlreadyDragged,
             updatedDraggedAlong) = self.updatePositionsHelper(
                item,
                [],
                translation,
                otherSelections: otherSelections,
                alreadyDragged: alreadyDragged,
                draggedAlong: draggedAlong)
        
        // limit this from going negative?
        cursorDrag.x = cursorDrag.previousX + translation.width
        
        item = self.items[originalItemIndex] // update the `item` too!
        alreadyDragged = alreadyDragged.union(updatedAlreadyDragged)
        draggedAlong = draggedAlong.union(updatedDraggedAlong)
        
        let calculatedIndex = self.calculateNewIndexOnDrag(
            item: item,
            otherSelections: otherSelections,
            draggedAlong: draggedAlong,
            movingDown: translation.height > 0,
            originalItemIndex: originalItemIndex,
            movedIndices: newIndices)
        
        self.maybeMoveIndices(
            originalItemId: item.id,
            indicesMoved: newIndices,
            to: calculatedIndex,
            originalIndex: originalItemIndex)
        
        
        // i.e. get the index of this dragged-item, given the updated masterList's items
        let updatedOriginalIndex = item.itemIndex(self.items)
        // update `item` again!
        item = self.items[updatedOriginalIndex]
        
        // should skip this for now?
        self.setItemsInGroupOrTopLevel(
            item: item,
            otherSelections: otherSelections,
            draggedAlong: draggedAlong,
            cursorDrag: cursorDrag)
        
        return draggedAlong
    }
}


//struct SidebarListItemDraggedResult {
//    let proposed: ProposedGroup?
//    let beingDragged: SidebarDraggedItem
//    let cursorDrag: SidebarCursorHorizontalDrag
//}

extension ProjectSidebarObservable {
    @MainActor
    func sidebarListItemDragEnded(itemId: Self.ItemID) {
    
        log("SidebarListItemDragEnded called: itemId: \(itemId)")

        let state = self
        var itemId = itemId
        
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.haveDuplicated {
        if state.selectionState.optionDragInProgress {
            // If we're currently doing an option+drag, then item needs to just be the top
            log("SidebarListItemDragged: had option drag and have already duplicated the layers")
            
            if let selectedItemWithSmallestIndex = Self.findSetItemWithSmallestIndex(
                from: state.selectionState.inspectorFocusedLayers.focused,
                in: state.orderedEncodedData.flattenedItems) {
                log("SidebarListItemDragged: had option drag, will use selectedItemWithSmallestIndex \(selectedItemWithSmallestIndex) as itemId")
                itemId = selectedItemWithSmallestIndex
            }
        }
        
        let item = state.items.first { $0.id == itemId }
        guard let item = item else {
            // if we couldn't find the item, it's been deleted
             log("SidebarListItemDragEnded: item \(itemId) was already deleted")
            return
        }

        // if no `current`, then we were just swiping?
        if let current = state.currentItemDragged {
            self.onSidebarListItemDragEnded(
                item,
                otherSelections: state.getOtherSelections(draggedItem: itemId),
                // MUST have a `current`
                // NO! ... this can be nil now eg when we call our onDragEnded logic via swipe
                draggedAlong: current.draggedAlong,
                proposed: state.proposedGroup)
        } else {
            log("SidebarListItemDragEnded: had no current, so will not do the full onDragEnded call")
        }

        // also reset: the potentially highlighted group,
        state.proposedGroup = nil
        // the current dragging item,
        state.currentItemDragged = nil
        // and the current x-drag tracking
        state.cursorDrag = nil
                
        state.selectionState.madeStack = false
        state.selectionState.haveDuplicated = false
        state.selectionState.optionDragInProgress = false
        state.implicitlyDragged = .init()
    
        state.graphDelegate?.encodeProjectInBackground()
    }
    
    @MainActor
    func onSidebarListItemDragEnded(_ item: Self.ItemViewModel,
                                    otherSelections: Set<Self.ItemID>,
                                    draggedAlong: Set<Self.ItemID>,
                                    proposed: ProposedGroup<Self.ItemID>?) {
        
        log("onSidebarListItemDragEnded called")
        
        item.zIndex = 0 // is this even used still?
        
        // finalizes items' positions by index;
        // also updates items' previousPositions.
        self.setYPositionByIndices(
            originalItemId: item.id,
            isDragEnded: true)
        
        let allDragged: [Self.ItemID] = [item.id] + Array(draggedAlong) + otherSelections
        
        // update both the X and Y in the previousLocation of the items that were moved;
        // ie `item` AND every id in `draggedAlong`
        for draggedId in allDragged {
            guard let draggedItem = self.retrieveItem(draggedId) else {
                fatalErrorIfDebug("Could not retrieve item")
                continue
            }
            draggedItem.previousLocation = draggedItem.location
//            items = updateSidebarListItem(draggedItem, items)
        }
        
        // reset the z-indices
        self.items.forEach {
            $0.zIndex = 0
        }
    }
}
