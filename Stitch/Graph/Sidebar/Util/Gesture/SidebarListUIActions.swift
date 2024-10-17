//
//  SidebarListUIActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import SwiftUI

// Actions related to modifying ui-state within the sidebar

// functions just for onDragged and onDragEnded

extension ProjectSidebarObservable {
    // you're just updating a single item
    // but need to update all the descendants as well?
    @MainActor
    func moveSidebarListItemIntoGroup(_ item: [ItemViewModel],
                                      otherSelections: Set<ItemViewModel.ID>,
                                      draggedAlong: Set<ItemViewModel.ID>,
                                      _ proposedGroup: ProposedGroup<ItemViewModel.ID>) {
        
        let newParent = proposedGroup.parentId
        
        // Every explicitly dragged item gets the new parent
        for otherSelection in ([item.id] + otherSelections) {
            guard var otherItem = items.first(where: { $0.id == otherSelection }) else {
                fatalErrorIfDebug("Could not retrieve item")
                continue
            }
            
            
            // TODO: update parent logic
//            otherItem.parentId = proposedGroup.parentId
            
            
            otherItem.location.x = proposedGroup.indentationLevel.toXLocation
            self.items = updateSidebarListItem(otherItem, items)
        }
        
        guard let updatedItem = self.retrieveItem(item.id) else {
            fatalErrorIfDebug("Could not retrieve item")
            return items
        }
        
        self.maybeSnapDescendants(updatedItem,
                                  draggedAlong: draggedAlong,
                                  startingIndentationLevel: proposedGroup.indentationLevel)
    }
    
    @MainActor
    func moveSidebarListItemToTopLevel(_ item: SidebarListItem,
                                       otherSelections: Set<ItemID>,
                                       draggedAlong: Set<ItemID>) {
        
        // Every explicitly dragged item gets its parent and indentation-level wiped
        for otherSelection in ([item.id] + otherSelections) {
            guard let otherItem = self.retrieveItem(otherSelection) else {
                fatalErrorIfDebug("Could not retrieve item")
                continue
            }
            
            // TODO: update parent logic
//            otherItem.parentId = nil
            
            
            otherItem.location.x = 0
        }
        
        guard let updatedItem = self.retrieveItem(item.id) else {
            fatalErrorIfDebug("Could not retrieve item")
        }
        
        self.maybeSnapDescendants(updatedItem,
                                  draggedAlong: draggedAlong,
                                  startingIndentationLevel: IndentationLevel(0))
    }
}


extension ProjectSidebarObservable {
    @MainActor
    func maybeSnapDescendants(_ item: Self.ItemViewModel,
                              draggedAlong: Set<ItemID>,
                              // the indentation level from the proposed group
                              // (if top level then = 0)
                              startingIndentationLevel: IndentationLevel) {
        
        log("maybeSnapDescendants: item at start: \(item)")
        
        let descendants = items.filter { draggedAlong.contains($0.id) }
        
        if descendants.isEmpty {
            log("maybeSnapDescendants: no children for this now-top-level item \(item.id); exiting early")
            return items
        }
        
        let indentDiff: Int = startingIndentationLevel.value - item.indentationLevel.value
        
        for child in descendants {
            let childExistingIndent = child.indentationLevel.value
            let newIndent = childExistingIndent + indentDiff
            let finalChildIndent = IndentationLevel(newIndent)
            child.setXLocationByIndentation(finalChildIndent)
        }
    }
}

extension SidebarItemSwipable {
    func setXLocationByIndentation(_ indentationLevel: IndentationLevel) {
        self.location.x = indentationLevel.toXLocation
    }
}

// accepts `parentIndentation`
// eg a child of a top level item will receive `parentIndentation = 50`
// and so child's x location must always be 50 greater than its parent
func updateYPosition(translation: CGSize,
                     location: CGPoint) -> CGPoint {
    CGPoint(x: location.x, // NEVER adjust x
            y: translation.height + location.y)
}

extension ProjectSidebarObservable {
    // ie We've just REORDERED `items`,
    // and now want to set their heights according to the REORDERED items.
    func setYPositionByIndices(originalItemId: Self.ItemID,
                               isDragEnded: Bool = false) {
        self.items.enumerated().forEach { (offset, item) in
            var item = item
            let newY = CGFloat(offset * CUSTOM_LIST_ITEM_VIEW_HEIGHT)
            
            if !isDragEnded && item.id == originalItemId {
                log("setYPositionByIndices: will not change originalItemId \(originalItemId)'s y-position until drag-is-ended")
            } else {
                item.location.y = newY
                if isDragEnded {
                    print("setYPositionByIndices: drag ended, so resetting previous position")
                    item.previousLocation.y = newY
                }
            }
        }
    }
}

extension Array where Element: SidebarItemSwipable {
    func wipeIndentationLevelsOfSelectedItems(selections: Set<Element.ID>) {
        self.forEach { item in
            if item.isSelected(selections) {
                item.location.x = 0
                item.previousLocation.x = 0
                item.parentId = nil // Also removes parent, if item is now top level
            }
        }
    }
}


//func removeSelectedItemsFromParents(items: SidebarListItems,
//                                    selections: LayerIdSet) -> SidebarListItems {
//    // Must also iterate through selected items and set their parentId = nil
//    items.map { (item: SidebarListItem) in
//        if selections.contains(item.id.asLayerNodeId) {
//            var item = item
//            item.parentId = nil
//            return item
//        } else {
//            return item
//        }
//    }
//}


extension ProjectSidebarObservable {
    // Grab the item immediately below;
    // if it has a parent (which should be above us),
    // use that parent as the proposed group.
    @MainActor
    func groupFromChildBelow(_ item: Self.ItemID,
                             movedItemChildrenCount: Int,
                             excludedGroups: ExcludedGroups) -> ProposedGroup<Self.ItemID>? {
        
        log("groupFromChildBelow: item: \(item)")
        // let debugItems = items.enumerated().map { ($0.offset, $0.element.layer) }
        // log("groupFromChildBelow: items: \(debugItems)")
        
        let movedItemIndex = item.itemIndex(items)
        
        let entireIndex = movedItemIndex + movedItemChildrenCount
        // log("groupFromChildBelow: entireIndex: \(entireIndex)")
        
        // must look at the index of the first item BELOW THE ENTIRE BEING-MOVED-ITEM-LIST
        let indexBelow: Int = entireIndex + 1
        
        // log("groupFromChildBelow: indexBelow: \(indexBelow)")
        
        guard let itemBelow = self.items[safeIndex: indexBelow] else {
            log("groupFromChildBelow: no itemBelow")
            return nil
        }
        
        log("groupFromChildBelow: itemBelow: \(itemBelow)")
        
        guard let parentOfItemBelow = itemBelow.parentId else {
            log("groupFromChildBelow: no parent on itemBelow")
            return nil
        }
        
        let itemsAbove = self.getItemsAbove(item)
        
        guard let parentItemAbove = itemsAbove.first(where: { $0.id == parentOfItemBelow }),
              // added:
              parentItemAbove.isGroup else {
            log("groupFromChildBelow: could not find parent above")
            return nil
        }
        
        log("groupFromChildBelow: parentItemAbove: \(parentItemAbove)")
        
        let proposedParent = parentItemAbove.id
        let proposedIndentation = parentItemAbove.indentationLevel.inc().toXLocation
        
        // we'll use the indentation level of the parent + 1
        return ProposedGroup(parentId: proposedParent,
                             xIndentation: proposedIndentation)
    }
    
    @MainActor
    func getItemsBelow(_ item: Self.ItemViewModel) -> [Self.ItemViewModel] {
        let movedItemIndex = item.itemIndex(items)
        // eg if movedItem's index is 5,
        // then items below have indices 6, 7, 8, ...
        return items.filter { $0.itemIndex(items) > movedItemIndex }
    }
    
    @MainActor
    func getItemsAbove(_ item: Self.ItemViewModel) -> [Self.ItemViewModel] {
        let movedItemIndex = item.itemIndex(items)
        // eg if movedItem's index is 5,
        // then items above have indices 4, 3, 2, ...
        return items.filter { $0.itemIndex(items) < movedItemIndex }
    }
    
    @MainActor
    func findDeepestParent(_ item: Self.ItemViewModel, // the moved-item
                           cursorDrag: Self.HorizontalDrag) -> ProposedGroup<Self.ItemID>? {
        
        var proposed: ProposedGroup<Self.ItemID>?
        
        log("findDeepestParent: item.id: \(item.id)")
        log("findDeepestParent: item.location.x: \(item.location.x)")
        log("findDeepestParent: cursorDrag: \(cursorDrag)")
        
        let excludedGroups = self.excludedGroups
        
        let itemLocationX = cursorDrag.x
        
        for itemAbove in getItemsAbove(item, items) {
            log("findDeepestParent: itemAbove.id: \(itemAbove.id)")
            log("findDeepestParent: itemAbove.location.x: \(itemAbove.location.x)")
            
            // Is this dragged item east of the above item?
            // Must be >, not >=, since = is for certain top level cases.
            if itemLocationX > itemAbove.location.x {
                let itemAboveHasChildren = self.hasChildren(itemAbove.id)
                
                // if the itemAbove us itself a parent,
                // then we want to put our being-dragged-item into that itemAbove's child list;
                // and NOT use that itemAbove's own parent as our group
                if itemAboveHasChildren,
                   !excludedGroups[itemAbove.id].isDefined,
                   itemAbove.isGroup {
                    log("found itemAbove that has children; will make being-dragged-item")
                    
                    // make sure it's not a closed group that we're proposing!
                    
                    proposed = ProposedGroup(parentId: itemAbove.id,
                                             xIndentation: itemAbove.indentationLevel.inc().toXLocation)
                }
                
                // this can't quite be right --
                // eg we can find an item above us that has its own parent,
                // we'd wrongly put the being-dragged-item into
                
                else if let itemAboveParentId = itemAbove.parentId,
                        !excludedGroups[itemAboveParentId].isDefined {
                    log("found itemAbove that is part of a group whose parent id is: \(itemAbove.parentId)")
                    proposed = ProposedGroup(
                        parentId: itemAboveParentId,
                        xIndentation: itemAbove.location.x)
                }
                
                // if the item above is NOT itself part of a group,
                // we'll just use the item above now as its parent
                else if !excludedGroups[itemAbove.id].isDefined,
                        item.isGroup {
                    log("found itemAbove without parent")
                    proposed = ProposedGroup(
                        parentId: itemAbove.id,
                        xIndentation: IndentationLevel(1).toXLocation)
                    // ^^^ if item has no parent ie is top level,
                    // then need this indentation to be at least one level
                }
                log("findDeepestParent: found proposed: \(proposed)")
                log("findDeepestParent: ... for itemAbove: \(itemAbove.id)")
            } else {
                log("\(item.id) was not at/east of itemAbove \(itemAbove.id)")
            }
        }
        log("findDeepestParent: final proposed: \(String(describing: proposed))")
        return proposed
    }
    
    // if we're blocked by a top level item,
    // then we ourselves must become a top level item
    @MainActor
    func blockedByTopLevelItemImmediatelyAbove(_ item: Self.ItemViewModel) -> Bool {
        
        let index = item.itemIndex(items)
        if let immediatelyAbove = items[safeIndex: index - 1],
           // `parentId: nil` = item is top level
           //       !immediatelyAbove.parentId.isDefined {
            
            // ie the item above us is not part of a group
            !immediatelyAbove.parentId.isDefined,
           
            // ... and not itself a group.
           // (if the item immediately above is a group,
            // then we should allow it to be proposed)
            !immediatelyAbove.isGroup {
            
            //        log("blocked by child-less top-level item immediately above")
            return true
        }
        return false
    }

    @MainActor
    func proposeGroup(_ item: Self.ItemViewModel, // the moved-item
                      _ draggedAlongCount: Int, // all dragged items, whether implicitly or explicitly selelected
                      cursorDrag: Self.HorizontalDrag) -> ProposedGroup<Self.ItemID>? {
        
        // Note: we do not need to filter out otherSelectons etc., which are inc
        
        // log("proposeGroup: will try to propose group for item: \(item.id)")
        
        // GENERAL RULE:
        var proposed = self.findDeepestParent(item,
                                              cursorDrag: cursorDrag)
        
        // Exceptions:
        
        // Does the item have a non-parent top-level it immediately above it?
        // if so, that blocks group proposal
        if self.blockedByTopLevelItemImmediatelyAbove(item) {
            log("proposeGroup: blocked by non-parent top-level item above")
            proposed = nil
        }
        
        if let groupDueToChildBelow = self.groupFromChildBelow(
            item,
            movedItemChildrenCount: draggedAlongCount,
            excludedGroups: self.excludedGroups) {
            
            log("proposeGroup: found group \(groupDueToChildBelow.parentId) from child below")
            
            // if our drag is east of the proposed-from-below's indentation level,
            // and we already found a proposed group from 'deepest parent',
            // then don't use proposed-from-below.
            let keepProposed = (groupDueToChildBelow.indentationLevel.toXLocation < cursorDrag.x) && proposed.isDefined
            
            if !keepProposed {
                log("proposeGroup: will use group from child below")
                proposed = groupDueToChildBelow
            }
        }
        
        log("proposeGroup: returning: \(String(describing: proposed))")
        
        if let proposedParentId = proposed?.parentId,
           let proposedParentItem = self.retrieveItem(proposedParentId),
           !proposedParentItem.isGroup {
            fatalErrorIfDebug() // Can never propose a parent that is not actually a group
            return nil
        }
        
        return proposed
    }
    
//    @MainActor
//    func updateSidebarListItem(_ item: Self.ItemViewModel) -> [Element] {
//        let index = item.itemIndex(items)
//        var items = items
//        self.items[index] = item
//        return items
//    }

    // used only during on drag;
    @MainActor
    func updatePositionsHelper(_ item: Self.ItemViewModel,
                               _ indicesToMove: [Int],
                               _ translation: CGSize,
                               
                               // doesn't change during drag gesture itself
                               otherSelections: Set<Self.ItemID>,
                               alreadyDragged: Set<Self.ItemID>,
                               // changes during drag gesture?
                               draggedAlong: Set<Self.ItemID>) -> ([Int],
                                                                   Set<Self.ItemID>,
                                                                   Set<Self.ItemID>) {
        
        // log("updatePositionsHelper for item \(item.id)")
        // log("updatePositionsHelper: alreadyDragged at start of helper: \(alreadyDragged)")
        
        // When called from top level, this is the ENTIRE `masterList.items`
        // ... and we never filter it, so we end up always passed
        
        var indicesToMove = indicesToMove
        var draggedAlong = draggedAlong
        
        // always update the item's position first:
        item.location = updateYPosition(
            translation: translation,
            location: item.previousLocation)
        
        indicesToMove.append(index)
        
        
        // Tricky: this recursively looks at every item in the last and checks whether we dragged its parent; if so, we adjust it
        
        var alreadyDragged = alreadyDragged // SidebarListItemIdSet()
        
        self.items.forEach { childItem in
            
            let isNotDraggedItem = childItem.id != item.id
            // This is the meat of this function -- is this child item the child of the parent we're dragging ?
            let isChildOfDraggedParent = childItem.parentId.map { $0 == item.id } ?? false
            
            let isOtherDragged = otherSelections.contains(childItem.id)
            
            let isNotAlreadyDragged = !alreadyDragged.contains(childItem.id)
            // log("updatePositionsHelper: childItem: \(childItem.id)")
            // log("updatePositionsHelper: isNotAlreadyDragged: \(isNotAlreadyDragged)")
            
            
            if isNotDraggedItem && isNotAlreadyDragged &&
                (isChildOfDraggedParent || isOtherDragged) {
                
                draggedAlong.insert(childItem.id)
                // log("updatePositionsHelper: alreadyDragged was: \(alreadyDragged)")
                alreadyDragged.insert(childItem.id)
                
                let (newIndices,
                     updatedAlreadyDragged,
                     updatedDraggedAlong) = self.updatePositionsHelper(
                        childItem,
                        indicesToMove,
                        translation,
                        otherSelections: otherSelections,
                        alreadyDragged: alreadyDragged,
                        draggedAlong: draggedAlong)
                
                indicesToMove = newIndices
                alreadyDragged = alreadyDragged.union(updatedAlreadyDragged)
                draggedAlong = draggedAlong.union(updatedDraggedAlong)
            } // if ...
            
        } // items.forEach
        
        return (indicesToMove, alreadyDragged, draggedAlong)
    }
}

func adjustMoveToIndex(calculatedIndex: Int,
                       originalItemIndex: Int,
                       movedIndices: [Int],
                       maxIndex: Int) -> Int {

    var calculatedIndex = calculatedIndex

    // Suppose we have [blue, black, green],
    // blue is black's parent,
    // and blue and green are both top level.
    // If we move blue down, `getMovedtoIndex` will give us a new index of 1 instead of 0.
    // But index 1 is the position of blue's child!
    // So we add the diff.
    if calculatedIndex > originalItemIndex {
        let diff = calculatedIndex - originalItemIndex
        print("adjustMoveToIndex: diff: \(diff)")
        
        // movedIndices is never going to be empty!
        // it always has at least a single item
        if movedIndices.isEmpty {
            //            calculatedIndex = calculatedIndex + diff
            calculatedIndex += diff
            print("adjustMoveToIndex: empty movedIndices: calculatedIndex is now: \(calculatedIndex)")
        } else {
            let maxMovedIndex = movedIndices.max()!
            print("adjustMoveToIndex: maxMovedIndex: \(maxMovedIndex)")
            calculatedIndex = maxMovedIndex + diff
            print("adjustMoveToIndex: nonEmpty movedIndices: calculatedIndex is now: \(calculatedIndex)")
        }
        
        if calculatedIndex > maxIndex {
            print("adjustMoveToIndex: calculatedIndex was too large, will use max index instead")
            calculatedIndex = maxIndex
        }
        return calculatedIndex

    } else {
        print("adjustMoveToIndex: Will NOT adjust moveTo index")
        return calculatedIndex
    }
}

extension ProjectSidebarObservable {
    func maybeMoveIndices(originalItemId: Self.ItemID,
                          indicesMoved: [Int],
                          to: Int,
                          originalIndex: Int) {
        if to != originalIndex {
            
            let finalOffset = to > originalIndex ? to + 1 : to
            
            items.move(fromOffsets: IndexSet(indicesMoved),
                       toOffset: finalOffset)
            
            self.setYPositionByIndices(
                originalItemId: originalItemId,
                isDragEnded: false)
            
        }
    }
}
