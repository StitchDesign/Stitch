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
        if self.currentItemDragged != itemId {
            self.currentItemDragged = itemId
        }
        
        if !self.isSidebarFocused {
            self.isSidebarFocused = true
        }
    }

    // Function to find the set item whose index in the list is the smallest
    @MainActor
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
    
    @MainActor
    func getDraggedAlong(_ draggedItem: Self.ItemViewModel,
                         selections: Set<Self.ItemID>) -> Set<Self.ItemID> {
        let children = draggedItem.children?.map { $0.id } ?? []
        
        return ([draggedItem.id] + children)
            .toSet
            .union(selections)
    }

    // Note: call this AFTER we've dragged and have a big list of all the 'dragged along' items
    @MainActor
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
        
        // log("sidebarListItemDragged: item.id \(item.id)")
        
        let state = self
        guard let graph = state.graphDelegate else {
            // log("sidebarListItemDragged: NO GRAPH")
            return
        }
        
        guard let document = graph.documentDelegate else {
            // log("sidebarListItemDragged: NO DOCUMENT")
            return
        }
        
        // The tracked dragged item may change if option + click
        var draggedItem = item
        
        // Focus sidebar
        if !self.isSidebarFocused {
            self.isSidebarFocused = true
        }
              
        // We have an in-progress option dupe-drag and have already duplicated the layers
        if state.selectionState.optionDragInProgress {
            // If we're currently doing an option+drag, then item needs to just be the top
            // log("SidebarListItemDragged: had option drag and have already duplicated the layers")
            
            if let selectedItemIdWithSmallestIndex = self.findSetItemWithSmallestIndex(
                from: state.selectionState.primary),
               let selectedItemWithSmallestIndex = self.items.get(selectedItemIdWithSmallestIndex) {
                // log("SidebarListItemDragged: had option drag, will use selectedItemWithSmallestIndex \(selectedItemWithSmallestIndex.id) as itemId")
                draggedItem = selectedItemWithSmallestIndex
            }
        }
        
        let focusedLayers = state.selectionState.primary
        
        // Dragging a layer not already selected = dragging just that layer and deselecting all the others
        if !focusedLayers.contains(draggedItem.id) {
            state.selectionState.resetEditModeSelections()
            state.sidebarItemSelectedViaEditMode(draggedItem.id)
            state.selectionState.lastFocused = draggedItem.id
        }
         
        // We're just starting an option dupe-drag and need to duplicate the layers
        if graph.keypressState.isOptionPressed
            && !state.selectionState.haveDuplicated
            && !state.selectionState.optionDragInProgress {
            // log("SidebarListItemDragged: option held during drag; will duplicate layers")
            
            let originalOptionDraggedLayer = item.id as? SidebarListItemId
            // log("SidebarListItemDragged: option held during drag; will duplicate layers: originalOptionDraggedLayer: \(originalOptionDraggedLayer)")
            
            state.selectionState.originalLayersPrimarilySelectedAtStartOfOptionDrag = selectionState.primary
            graph.sidebarSelectedItemsDuplicated(originalOptionDraggedLayer: originalOptionDraggedLayer,
                                                 document: document)
            state.selectionState.haveDuplicated = true
            state.selectionState.optionDragInProgress = true
            
            return
        }
        
        // If we have multiple layers already selected and are dragging one of these already-selected layers,
        // we create a "stack" (reorganization of selected layers) and treat the first layer in the stack as the user-dragged layer.
        
        // do we need this `else if` ?
        if focusedLayers.count > 1 {
            if let selectedItemIdWithSmallestIndex = self.findSetItemWithSmallestIndex(from: state.selectionState.all),
               let selectedItemWithSmallestIndex = self.items.get(selectedItemIdWithSmallestIndex),
               draggedItem.id != selectedItemIdWithSmallestIndex {
               
               // If we had mutiple layers focused, the "dragged item" should be the top item
               // (Note: we'll also move all the potentially-disparate/island'd layers into a single stack; so we may want to do this AFTER the items are all stacked? or we're just concerned about the dragged-item, not its index per se?)
                draggedItem = selectedItemWithSmallestIndex
                // log("SidebarListItemDragged item is now \(selectedItemWithSmallestIndex) ")
           }
        }
        
        self.onSidebarListItemDragged(translation)
    }
    
    @MainActor
    func onSidebarListItemDragged(_ translation: CGSize) {
        let visualList = self.getVisualFlattenedList()
        
        // Track old count before selections are made below
        // In-place removals mean we need to save this now
        let oldCount = visualList.count

        let allSelections = self.selectionState
            .primary
        
        // Important to keep items in sorted order
        let allDraggedItems = visualList.filter { item in
            allSelections.contains(item.id)
        }
        
        let allDraggedItemIds = allDraggedItems.map(\.id).toSet
        
        // Includes visible children of dragged nodes (aka implicitly dragged)
        let allDraggedItemsPlusChildren = self.items.getSubset(from: allDraggedItemIds)
            .getFlattenedVisibleItems(selectedIds: allSelections)
        
        guard let firstDraggedItem = allDraggedItems.first else {
            fatalErrorIfDebug()
            return
        }
        
        let isNewDrag = firstDraggedItem.dragPosition == nil

        // Remove dragged items from data structure used for identifying drag location
        let filteredVisualList = visualList.filter { item in
            !allDraggedItemsPlusChildren.contains(where: { $0.id == item.id })
        }
        
        let originalItemIndex = firstDraggedItem.sidebarIndex
                
        // Set state for a new drag
        if isNewDrag {
            self.currentItemDragged = firstDraggedItem.id
            // Set up previous drag position, which we'll increment off of
            allDraggedItemsPlusChildren.enumerated().forEach { index, item in
                let initialPosition = CGPoint(x: item.location.x,
                                              y: firstDraggedItem.location.y + (SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT * CGFloat(index)))
                item.prevDragPosition = initialPosition
                item.dragPosition = item.prevDragPosition
            }
        }
    
        guard let firstDragPosition = firstDraggedItem.dragPosition else {
            fatalErrorIfDebug()
            return
        }
        
        // Dragging down = indices increase
//        let isDraggingDown = (item.dragPosition?.y ?? .zero) > oldDragPosition.y
        
        // Update drag positions
        allDraggedItemsPlusChildren.forEach { draggedItem in
            draggedItem.dragPosition = (draggedItem.prevDragPosition ?? .zero) + translation.toCGPoint
        }
        
        guard let calculatedIndex = Self.getMovedtoIndex(
            firstItemLocation: firstDragPosition,
            movingDown: translation.height > 0,
            flattenedItems: filteredVisualList,
            maxRowIndex: visualList.count - 1) else {
            // log("onSidebarListItemDragged: no index found")
            return
        }
        
        
        if originalItemIndex != calculatedIndex || isNewDrag {
            self.movedDraggedItems(draggedElement: firstDraggedItem,
                                   draggedItems: allDraggedItems,
                                   visualList: filteredVisualList,
                                   to: calculatedIndex,
                                   draggedItemsPlusChildrenCount: allDraggedItemsPlusChildren.count,
                                   oldCount: oldCount)
        }
    }
    
    /// Filters out collapsed groups.
    /// List mut be flattened for drag gestures.
    @MainActor
    func getVisualFlattenedList() -> [Self.ItemViewModel] {
        self.items.getVisualFlattenedList()
    }
    
    @MainActor
    func movedDraggedItems(draggedElement: Self.ItemViewModel,
                           draggedItems: [Self.ItemViewModel],
                           visualList: [Self.ItemViewModel],
                           to index: SidebarIndex,
                           draggedItemsPlusChildrenCount: Int,
                           oldCount: Int) {
        let visualList = visualList
        let draggedItemIdSet = draggedItems.map(\.id).toSet
        
        let draggedToElementResult = visualList.findClosestElement(
            draggedElement: draggedElement,
            to: index,
            numItemsDragged: draggedItemsPlusChildrenCount)
                
        // We should have removed dragged elements from the visual list
        assertInDebug(!draggedItems.contains(where: { $0.id == draggedToElementResult.id }))
        
        // Remove items from dragged set--these will be added later
        var reducedItemsList = self.items
        reducedItemsList.remove(draggedItemIdSet)
        
        guard !draggedItems.isEmpty else { return }
        
        let newItemsList = reducedItemsList.movedDraggedItems(draggedItems,
                                                              at: draggedToElementResult,
                                                              dragPositionIndex: index)
        
#if DEBUG || DEV_DEBUG
        let newFlattenedList = newItemsList.getVisualFlattenedList()
        let newFlattenedListIds = newFlattenedList.map(\.id)
        
        // Don't use assert test after movedDraggedItems because of references to self list
        assert(newFlattenedList.count == oldCount)
        assert(newFlattenedListIds.count == Set(newFlattenedListIds).count)
#endif
        self.items = newItemsList
        self.items.updateSidebarIndices()
        
        // TODO: should only be for layers sidebar
        self.graphDelegate?.updateOrderedPreviewLayers()
    }
}

extension ProjectSidebarObservable {
    @MainActor
    func sidebarListItemDragEnded() {
    
//        log("sidebarListItemDragEnded called")

        let state = self
        
        self.items.flattenedItems.forEach {
            $0.dragPosition = nil
            $0.prevDragPosition = nil
        }

        self.currentItemDragged = nil

        // reset the current dragging item
        state.currentItemDragged = nil

        state.selectionState.haveDuplicated = false
        state.selectionState.optionDragInProgress = false
        state.selectionState.originalLayersPrimarilySelectedAtStartOfOptionDrag = .init()
    
        state.graphDelegate?.encodeProjectInBackground()
    }
}
