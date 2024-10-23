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
    func sidebarListItemLongPressed(itemId: Self.ItemID) {
        self.currentItemDragged = itemId
    }

    // Function to find the set item whose index in the list is the smallest
    func findSetItemWithSmallestIndex(from set: Set<Self.ItemID>) -> Self.ItemID? {
        var smallestIndex: Int? = nil
        var smallestItem: Self.ItemID? = nil
        
        // Iterate through each item in the set
        for item in set {
            if let index = self.items.flattenedItems.firstIndex(where: { $0.id == item }) {
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
    
    func getDraggedAlong(_ draggedItem: Self.ItemViewModel,
                         selections: Set<Self.ItemID>) -> Set<Self.ItemID> {
        let children = draggedItem.children?.map { $0.id } ?? []
        
        return ([draggedItem.id] + children)
            .toSet
            .union(selections)
    }

    // Note: call this AFTER we've dragged and have a big list of all the 'dragged along' items
    func getImplicitlyDragged(draggedAlong: Set<ItemID>,
                              selections: Set<ItemID>) -> Set<ItemID> {
        
        self.items.flattenedItems.reduce(into: Set<ItemID>()) { partialResult, item in
            // if the item was NOT selected, yet was dragged along,
            // then it is "implicitly" selected
            if !selections.contains(item.id),
               draggedAlong.contains(item.id) {
                partialResult.insert(item.id)
            }
        }
    }
    
    @MainActor
    func sidebarListItemDragged(item: Self.ItemViewModel,
                                translation: CGSize) {
        
        // log("SidebarListItemDragged called: item \(itemId) ")
        guard let graph = self.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let state = self
        var itemId = item.id
        
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.haveDuplicated {
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.optionDragInProgress {
        if state.selectionState.optionDragInProgress {
            // If we're currently doing an option+drag, then item needs to just be the top
            log("SidebarListItemDragged: had option drag and have already duplicated the layers")
            
            if let selectedItemWithSmallestIndex = self.findSetItemWithSmallestIndex(
                from: state.inspectorFocusedLayers.focused) {
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
                let item = self.items.get(itemId),
            
                self.updateStackOnDrag(
                    item,
                    selections: state.selectionState.inspectorFocusedLayers.focused) {
                
                state.selectionState.madeStack = true
            }
            
            if let selectedItemWithSmallestIndex = self.findSetItemWithSmallestIndex(
                from: state.selectionState.inspectorFocusedLayers.focused),
               itemId != selectedItemWithSmallestIndex {
               
               // If we had mutiple layers focused, the "dragged item" should be the top item
               // (Note: we'll also move all the potentially-disparate/island'd layers into a single stack; so we may want to do this AFTER the items are all stacked? or we're just concerned about the dragged-item, not its index per se?)
               itemId = selectedItemWithSmallestIndex
               // log("SidebarListItemDragged item is now \(selectedItemWithSmallestIndex) ")
           }
        }
        
        let otherSelections = state.getOtherSelections(draggedItem: itemId)
        // log("SidebarListItemDragged: otherDragged \(otherSelections) ")

        self.onSidebarListItemDragged(
            item, // this dragged item
            translation, // drag data
            // ALL items
            otherSelections: otherSelections)
    }
    
    @MainActor
    func onSidebarListItemDragged(_ item: Self.ItemViewModel, // assumes we've already
                                  _ translation: CGSize,
                                  otherSelections: Set<ItemID>) {
        let visualList = self.getVisualFlattenedList()

        let allDraggedItems = [item] + visualList.filter { item in
            otherSelections.contains(item.id)
        }

        let implicitlyDraggedItems = visualList.filter { item in
            self.implicitlyDragged.contains(item.id)
        }
        
        // Remove dragged items from data structure used for identifying drag location
        let filteredVisualList = visualList.filter { item in
            !(allDraggedItems + implicitlyDraggedItems).contains(where: { $0.id == item.id })
        }
        
        let originalItemIndex = item.sidebarIndex
        
        // New drag check
        guard let oldDragPosition = item.dragPosition else {
            // TODO: If new drag, re-arrange groups and delete
            
            self.currentItemDragged = item.id
            
            // Remove elements from groups if there are selections inside other selected groups
            Self.removeSelectionsFromGroups(selections: allDraggedItems)
            
            // Move items to dragged item
            self.movedDraggedItems(allDraggedItems,
                                   visualList: filteredVisualList,
                                   to: originalItemIndex)
            
            let draggedChildren = allDraggedItems.flatMap { draggedItem in
                draggedItem.children?.flattenedItems ?? []
            }
            
            // Update "implicitly dragged" (aka children of dragged parent items)
            self.implicitlyDragged = draggedChildren.map(\.id).toSet

            // Set up previous drag position, which we'll increment off of
            (allDraggedItems + draggedChildren).forEach { item in
                item.prevDragPosition = item.location
                item.dragPosition = item.prevDragPosition
            }
            
            return
        }
        
        // Update drag positions
        (allDraggedItems + implicitlyDraggedItems).forEach { draggedItem in
            draggedItem.dragPosition = (draggedItem.prevDragPosition ?? .zero) + translation.toCGPoint
        }
        
        // Dragging down = indices increase
        let isDraggingDown = (item.dragPosition?.y ?? .zero) > oldDragPosition.y
        
        guard let calculatedIndex = Self.getMovedtoIndex(
            dragPosition: item.dragPosition ?? item.location,
            movingDown: isDraggingDown,
            flattenedItems: filteredVisualList) else {
            log("No index found")
            return
        }
        
        if originalItemIndex != calculatedIndex {
            self.movedDraggedItems(allDraggedItems,
                                   visualList: filteredVisualList,
                                   to: calculatedIndex)
        }
    }
    
    /// Filters out collapsed groups.
    /// List mut be flattened for drag gestures.
    func getVisualFlattenedList() -> [Self.ItemViewModel] {
        self.items.getVisualFlattenedList()
    }
    
    @MainActor
    func movedDraggedItems(_ draggedItems: [Self.ItemViewModel],
                           visualList: [Self.ItemViewModel],
                           to index: SidebarIndex) {
        
        guard let firstDraggedElement = draggedItems.first else {
            return
        }
        
        let flattenedList = self.items.flattenedItems
        
        var newItemsList = self.items
        let visualList = visualList
        let draggedItems = draggedItems
        let oldCount = flattenedList.count
        let draggedItemIdSet = draggedItems.map(\.id).toSet
        
        let draggedToElementResult = visualList.findClosestElement(draggedElement: firstDraggedElement,
                                                                   to: index)
        
        // We should have removed dragged elements from the visual list
        assertInDebug(!draggedItems.contains(where: { $0.id == draggedToElementResult.id }))

        // Remove items from dragged set--these will be added later
        newItemsList.remove(draggedItemIdSet)
        
        guard !draggedItems.isEmpty else { return }
        
        newItemsList = newItemsList.movedDraggedItems(draggedItems,
                                                      at: draggedToElementResult,
                                                      dragPositionIndex: index)
        
        // Don't use assert test after movedDraggedItems because of references to self list
        
        self.items = newItemsList
        self.items.updateSidebarIndices()
        
        // TODO: should only be for layers sidebar
        self.graphDelegate?.updateOrderedPreviewLayers()
    }
    
    /// Removes selected elements from other selected groups.
    static func removeSelectionsFromGroups(selections: [Self.ItemViewModel]) {
        var queue = selections
        
        // Traverse backwards by exploring parent delegate
        while let element = queue.popLast() {
            guard let parent = element.parentDelegate else { continue }
            
            if selections.contains(where: { $0.id == parent.id }) {
                parent.children?.remove(element.id)
            }
            
            queue.append(parent)
        }
    }
}

extension ProjectSidebarObservable {
    @MainActor
    func sidebarListItemDragEnded() {
    
//        log("SidebarListItemDragEnded called: itemId: \(itemId)")

        let state = self
        
        // TODO: option click on end
//        var itemId = itemId
        
//        if state.keypressState.isOptionPressed && state.sidebarSelectionState.haveDuplicated {
//        if state.selectionState.optionDragInProgress {
//            // If we're currently doing an option+drag, then item needs to just be the top
//            log("SidebarListItemDragged: had option drag and have already duplicated the layers")
//            
//            if let selectedItemWithSmallestIndex = findSetItemWithSmallestIndex(
//                from: state.selectionState.inspectorFocusedLayers.focused) {
//                log("SidebarListItemDragged: had option drag, will use selectedItemWithSmallestIndex \(selectedItemWithSmallestIndex) as itemId")
//                itemId = selectedItemWithSmallestIndex
//            }
//        }
        
        self.items.flattenedItems.forEach {
            $0.dragPosition = nil
            $0.prevDragPosition = nil
        }

        self.currentItemDragged = nil

        // reset the current dragging item
        state.currentItemDragged = nil
                
        state.selectionState.madeStack = false
        state.selectionState.haveDuplicated = false
        state.selectionState.optionDragInProgress = false
        state.implicitlyDragged = .init()
    
        state.graphDelegate?.encodeProjectInBackground()
    }
}
