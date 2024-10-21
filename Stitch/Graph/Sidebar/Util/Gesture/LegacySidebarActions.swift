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
//        SidebarDraggedItem(
//            current: id,
//            // can be empty just because
//            // we're first starting the drag
//            draggedAlong: .init())
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
    
//    func getDraggedAlongHelper(item: Self.ItemID,
//                               acc: Set<Self.ItemID>) -> Set<Self.ItemID> {
//        var acc = acc
//        acc.insert(item)
//        
//        let children = self.items.filter { $0.parentId == item }
//        children.forEach { child in
//            let updatedAcc = getDraggedAlongHelper(item: child.id,
//                                                   acc: acc)
//            acc = acc.union(updatedAcc)
//        }
//        
//        return acc
//    }
    
    func getDraggedAlong(_ draggedItem: Self.ItemViewModel,
                         selections: Set<Self.ItemID>) -> Set<Self.ItemID> {
        let children = draggedItem.children?.map { $0.id } ?? []
        
        return ([draggedItem.id] + children)
            .toSet
            .union(selections)
        
//        var acc = acc
//        
//        let explicitlyDraggedItems = selections.union([draggedItem.id])
//        
//        explicitlyDraggedItems.forEach { explicitlyDraggedItem in
//            let updatedAcc = self
//                .getDraggedAlongHelper(item: explicitlyDraggedItem,
//                                       acc: acc)
//            acc = acc.union(updatedAcc)
//        }
//        
//        return acc
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

//        guard let item = state.items.get(where: { $0.id == itemId }) else {
//            // if we couldn't find the item, it's been deleted
//            fatalErrorIfDebug("SidebarListItemDragged: item \(itemId) was already deleted")
//            return
//        }
        
        let otherSelections = state.getOtherSelections(draggedItem: itemId)
        // log("SidebarListItemDragged: otherDragged \(otherSelections) ")

        self.onSidebarListItemDragged(
            item, // this dragged item
            translation, // drag data
            // ALL items
            otherSelections: otherSelections)
        
        // JUST USED FOR UI PURPOSES, color changes etc.
//        let implicitlyDragged = self.getImplicitlyDragged(
//            draggedAlong: draggedAlong,
//            selections: state.selectionState.inspectorFocusedLayers.focused)
//        state.implicitlyDragged = implicitlyDragged
                        
        // Need to update the preview window then
//        _updateStateAfterListChange(
//            updatedList: state.sidebarListState,
//            expanded: state.getSidebarExpandedItems(),
//            graphState: state)
        
        // Recalculate the ordered-preview-layers
//        state.graphDelegate?.updateOrderedPreviewLayers()
    }
    
    @MainActor
    func onSidebarListItemDragged(_ item: Self.ItemViewModel, // assumes we've already
                                  _ translation: CGSize,
                                  otherSelections: Set<ItemID>) {
        let visualList = self.getVisualFlattenedList()
        
        // log("onSidebarListItemDragged called: item.id: \(item.id)")
        let isDraggingDown = translation.height > 0
        
//        var alreadyDragged = Set<ItemID>()
//        var draggedAlong = Set<ItemID>()
        
        // log("onSidebarListItemDragged: otherSelections: \(otherSelections)")
        // log("onSidebarListItemDragged: draggedAlong: \(draggedAlong)")
        
        // TODO: remove this property, and use an `isBeingDragged` check in the UI instead?
//        if item.zIndex != SIDEBAR_ITEM_MAX_Z_INDEX {
//            item.zIndex = SIDEBAR_ITEM_MAX_Z_INDEX
//        }
        
        let allDraggedItems = [item] + visualList.filter { item in
            otherSelections.contains(item.id)
        }

        let implicitlyDraggedItems = visualList.filter { item in
            self.implicitlyDragged.contains(item.id)
        }
        
        // First time this is called, we pass in ALL items
//        let (newIndices,
//             updatedAlreadyDragged,
//             updatedDraggedAlong) = self.updatePositionsHelper(
//                item,
//                [],
//                translation,
//                otherSelections: otherSelections,
//                alreadyDragged: alreadyDragged,
//                draggedAlong: draggedAlong)
//        
        // limit this from going negative?
//        cursorDrag.x = cursorDrag.previousX + translation.width
//
////        item = self.items[originalItemIndex] // update the `item` too!
//        alreadyDragged = alreadyDragged.union(updatedAlreadyDragged)
//        draggedAlong = draggedAlong.union(updatedDraggedAlong)
        
        let originalItemIndex = item.sidebarIndex
        
//        let calculatedIndex = self.calculateNewIndexOnDrag(
//            item: item,
//            otherSelections: otherSelections,
////            draggedAlong: draggedAlong,
//            movingDown: translation.height > 0)
//            originalItemIndex: originalItemIndex,
//            movedIndices: newIndices)
//        
//        print("index: \(calculatedIndex)")
//
        
        // New drag check
        guard let dragPosition = item.dragPosition,
        let prevDragPosition = item.prevDragPosition else {
            // TODO: If new drag, re-arrange groups and delete
            
            self.currentItemDragged = item.id
            
            // TODO: filter selected items given groups
            
            // Move items to dragged item
            self.movedDraggedItems(allDraggedItems,
                                   visualList: visualList,
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
        
        let horizontalDragOffset = dragPosition.x - prevDragPosition.x
        
        (allDraggedItems + implicitlyDraggedItems).forEach { draggedItem in
            draggedItem.dragPosition = (draggedItem.prevDragPosition ?? .zero) + translation.toCGPoint
            
//            if originalItemIndex != calculatedIndex {
//                log("calculatedIndex: \(calculatedIndex)")
                // TODO: find element at new index
                // if child of dragged item, do nothing
                // else use helper to find array. decrement counter. when 0, place item there after removing old one
                
//                self.items.move(fromOffsets: <#T##IndexSet#>, toOffset: <#T##Int#>)
//                self.items.remove(item.id)
//            }
        }
        
        guard let calculatedIndex = Self.getMovedtoIndex(
            dragPosition: dragPosition,
//            maxIndex: maxMovedToIndex,
            movingDown: isDraggingDown,
            flattenedItems: visualList) else {
            log("No index found")
            return
        }
        
        log("new index: \(calculatedIndex)")
        if originalItemIndex != calculatedIndex {
            self.movedDraggedItems(allDraggedItems,
                                   visualList: visualList,
                                   to: calculatedIndex)
        }
        
////        self.maybeMoveIndices(
////            originalItemId: item.id,
////            indicesMoved: newIndices,
////            to: calculatedIndex,
////            originalIndex: originalItemIndex)
//        
//        
//        // i.e. get the index of this dragged-item, given the updated masterList's items
//        let updatedOriginalIndex = item.itemIndex(self.items)
//        // update `item` again!
//        item = self.items[updatedOriginalIndex]
//        
//        // should skip this for now?
//        self.setItemsInGroupOrTopLevel(
//            item: item,
//            otherSelections: otherSelections,
//            draggedAlong: draggedAlong)
//        
//        return draggedAlong
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
        var newItemsList = self.items
        let draggedItems = draggedItems
        
        guard let draggedToElement = visualList[safe: index.rowIndex] ?? visualList.last else {
            self.items = draggedItems
            return
        }
        
        log("draggedTo: \(draggedToElement.id)\tindex: \(index)")
        
        // Skip if we dragged to item that's a member of the dragged set--this is incompatible
        let allDraggedItems = draggedItems.flatMap { $0.allElementIds }
        let isDestinationMemberOfDraggedSet = allDraggedItems.contains(draggedToElement.id)
        guard !isDestinationMemberOfDraggedSet else { return }
        
        guard let location = visualList.getNestedListLocation(of: draggedToElement.id) else {
//            fatalErrorIfDebug()
            return
        }
        
        draggedItems.forEach {
            newItemsList.remove($0.id)
        }

        guard !draggedItems.isEmpty else { return }
        
        newItemsList = newItemsList.movedDraggedItems(draggedItems, at: location)
        
//        assertInDebug(newItemsList.flattenedItems.count == oldCount)
        
        self.items = newItemsList
        self.items.updateSidebarIndices()
        
        // TODO: should only be for layers sidebar
        self.graphDelegate?.updateOrderedPreviewLayers()
    }
}

struct NestedListLocation<Element: SidebarItemSwipable> {
    var associatedItemId: Element.ID?
    let type: NestedListLocationType
}

enum NestedListLocationType {
    case topOfHierarchy
    case afterItem
}

extension Array where Element: SidebarItemSwipable {
    /// Returns result which helps us determine location to drop items in a nested list.
    func getNestedListLocation(of elementId: Element.ID,
                               currentParent: Element.ID? = nil) -> NestedListLocation<Element>? {
        guard let foundIndex = self.firstIndex(where: { $0.id == elementId }) else {
            for child in self {
                if let result = child.children?.getNestedListLocation(of: elementId,
                                                                      currentParent: child.id) {
                    return result
                }
            }
            
            // TODO: unclear if this is bad
            fatalErrorIfDebug("No match found.")
            return nil
        }

        if foundIndex == 0 {
            return .init(associatedItemId: currentParent,
                         type: .topOfHierarchy)
        } else {
            return .init(associatedItemId: elementId,
                         type: .afterItem)
        }
    }
    
    /// Helper that recursively travels nested data structure.
    func recursiveForEach(_ callback: @escaping (Element) -> ()) {
        self.forEach { item in
            callback(item)
            
            item.children?.recursiveForEach(callback)
        }
    }
    
    /// Filters out collapsed groups.
    /// List mut be flattened for drag gestures.
    func getVisualFlattenedList() -> [Element] {
        self.flatMap { item in
            if let children = item.children,
               item.isExpandedInSidebar ?? false {
                return [item] + children.getVisualFlattenedList()
            }
            
            return [item]
        }
    }
    
//    /// Helper that recursively travels nested data structure.
//    func recursiveMap<T>(_ callback: @escaping (Element) -> T) -> [T] {
//        self.map { item in
//            let newItem = callback(item)
//            item.children = item.children?.map(callback)
//            return newItem
//        }
//    }
    
    @MainActor
    private func movedDraggedItemsToChildren(_ draggedItems: [Element],
                                             at location: NestedListLocation<Element>) -> [Element] {
        // Recursively check other children
        self.map { child in
            if let children = child.children {
                child.children = children.movedDraggedItems(draggedItems, at: location)
            }
            
            return child
        }
    }
    
    @MainActor
    mutating private func insertDraggedElements(_ elements: [Element],
                                                at index: Int) {
        self.insert(contentsOf: elements, at: index)
    }
    
    /// Recursive function that traverses nested array until index == 0.
    @MainActor
    func movedDraggedItems(_ draggedItems: [Element],
                           at location: NestedListLocation<Element>) -> [Element] {
        
        var newList = self
        
        switch location.type {
        case .topOfHierarchy:
            guard let parentId = location.associatedItemId else {
                // Nil case means root list
                newList.insertDraggedElements(draggedItems, at: 0)
                return newList
            }
            
            newList = newList.map { element in
                guard element.id == parentId else {
                    return element
                }
                
                if var children = element.children {
                    children.insertDraggedElements(draggedItems, at: 0)
                    element.children = children
                }
                
                return element
            }
            return newList
            
        case .afterItem:
            guard let itemId = location.associatedItemId,
                  let element = self.get(itemId),
                  let indexOfElement = self.firstIndex(where: { element.id == $0.id }) else {
                newList = newList.movedDraggedItemsToChildren(draggedItems, at: location)
                return newList
            }
            
            newList.insertDraggedElements(draggedItems, at: indexOfElement)
            return newList
        }
    }
}

//struct SidebarListItemDraggedResult {
//    let proposed: ProposedGroup?
//    let beingDragged: SidebarDraggedItem
//    let cursorDrag: SidebarCursorHorizontalDrag
//}

extension ProjectSidebarObservable {
    @MainActor
    func sidebarListItemDragEnded() {
    
//        log("SidebarListItemDragEnded called: itemId: \(itemId)")

        let state = self
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

        // if no `current`, then we were just swiping?
//        if let current = state.currentItemDragged {
//            self.onSidebarListItemDragEnded(
//                item,
//                otherSelections: state.getOtherSelections(draggedItem: itemId),
//                // MUST have a `current`
//                // NO! ... this can be nil now eg when we call our onDragEnded logic via swipe
//                draggedAlong: current.draggedAlong,
//                proposed: state.proposedGroup)
//        } else {
//            log("SidebarListItemDragEnded: had no current, so will not do the full onDragEnded call")
//        }

        // also reset: the potentially highlighted group,
//        state.proposedGroup = nil
        // the current dragging item,
        state.currentItemDragged = nil
        // and the current x-drag tracking
//        state.cursorDrag = nil
                
        state.selectionState.madeStack = false
        state.selectionState.haveDuplicated = false
        state.selectionState.optionDragInProgress = false
        state.implicitlyDragged = .init()
    
        state.graphDelegate?.encodeProjectInBackground()
    }
    
//    @MainActor
//    func onSidebarListItemDragEnded(_ item: Self.ItemViewModel,
//                                    otherSelections: Set<Self.ItemID>,
//                                    draggedAlong: Set<Self.ItemID>,
//                                    proposed: ProposedGroup<Self.ItemID>?) {
//        
//        log("onSidebarListItemDragEnded called")
//        
////        item.zIndex = 0 // is this even used still?
//        
//        // finalizes items' positions by index;
//        // also updates items' previousPositions.
//        self.setYPositionByIndices(
//            originalItemId: item.id,
//            isDragEnded: true)
//        
//        let allDragged: [Self.ItemID] = [item.id] + Array(draggedAlong) + otherSelections
//        
//        // update both the X and Y in the previousLocation of the items that were moved;
//        // ie `item` AND every id in `draggedAlong`
//        for draggedId in allDragged {
//            guard let draggedItem = self.retrieveItem(draggedId) else {
//                fatalErrorIfDebug("Could not retrieve item")
//                continue
//            }
//            draggedItem.previousLocation = draggedItem.location
////            items = updateSidebarListItem(draggedItem, items)
//        }
//        
//        // reset the z-indices
////        self.items.forEach {
////            $0.zIndex = 0
////        }
//    }
}
