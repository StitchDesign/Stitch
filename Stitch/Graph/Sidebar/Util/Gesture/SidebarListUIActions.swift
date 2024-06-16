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

// you're just updating a single item
// but need to update all the descendants as well?
func moveSidebarListItemIntoGroup(_ item: SidebarListItem,
                                  _ items: SidebarListItems,
                                  draggedAlong: SidebarListItemIdSet,
                                  _ proposedGroup: ProposedGroup) -> SidebarListItems {
    var item = item
    var items = items
    item.parentId = proposedGroup.parentId
    item.location.x = proposedGroup.indentationLevel.toXLocation
    items = updateSidebarListItem(item, items)
    let updatedItem = retrieveItem(item.id, items)

    return maybeSnapDescendants(updatedItem,
                                items,
                                draggedAlong: draggedAlong,
                                startingIndentationLevel: proposedGroup.indentationLevel)
}

func moveSidebarListItemToTopLevel(_ item: SidebarListItem,
                                   _ items: SidebarListItems,
                                   draggedAlong: SidebarListItemIdSet) -> SidebarListItems {

    var item = item
    var items = items

    // top level items have no parent,
    // and have x = 0 indentation
    item.parentId = nil
    item.location.x = 0

    items = updateSidebarListItem(item, items)
    let updatedItem = retrieveItem(item.id, items)
    //    log("moveItemToTopLevel: updatedItem: \(updatedItem)")

    return maybeSnapDescendants(updatedItem,
                                items,
                                draggedAlong: draggedAlong,
                                startingIndentationLevel: IndentationLevel(0))

}

func maybeSnapDescendants(_ item: SidebarListItem,
                          _ items: SidebarListItems,
                          draggedAlong: SidebarListItemIdSet,
                          // the indentation level from the proposed group
                          // (if top level then = 0)
                          startingIndentationLevel: IndentationLevel) -> SidebarListItems {

    //    log("maybeSnapDescendants: item at start: \(item)")

    let descendants = items.filter { draggedAlong.contains($0.id) }

    if descendants.isEmpty {
        //        log("maybeSnapDescendants: no children for this now-top-level item \(item.id); exiting early")
        return items
    }

    let indentDiff: Int = startingIndentationLevel.value - item.indentationLevel.value

    var items = items

    for child in descendants {
        var child = child
        let childExistingIndent = child.indentationLevel.value
        let newIndent = childExistingIndent + indentDiff
        let finalChildIndent = IndentationLevel(newIndent)
        child = setXLocationByIndentation(child, finalChildIndent)
        items = updateSidebarListItem(child, items)
    }

    return items
}

func setXLocationByIndentation(_ item: SidebarListItem,
                               _ indentationLevel: IndentationLevel) -> SidebarListItem {
    var item = item
    item.location.x = indentationLevel.toXLocation
    return item
}

// accepts `parentIndentation`
// eg a child of a top level item will receive `parentIndentation = 50`
// and so child's x location must always be 50 greater than its parent
func updateYPosition(translation: CGSize,
                     location: CGPoint) -> CGPoint {
    CGPoint(x: location.x, // NEVER adjust x
            y: translation.height + location.y)
}

// ie We've just REORDERED `items`,
// and now want to set their heights according to the REORDERED items.
func setYPositionByIndices(originalItemId: SidebarListItemId,
                           _ items: SidebarListItems,
                           isDragEnded: Bool = false) -> SidebarListItems {

    items.enumerated().map { (offset, item) in
        var item = item
        let newY = CGFloat(offset * CUSTOM_LIST_ITEM_VIEW_HEIGHT)

        if !isDragEnded && item.id == originalItemId {
            //            print("setYPositionByIndices: will not change originalItemId \(originalItemId)'s y-position until drag-is-ended")
            return item
        } else {
            item.location.y = newY
            if isDragEnded {
                //            print("setYPositionByIndices: drag ended, so resetting previous position")
                item.previousLocation.y = newY
            }
            return item
        }
    }
}

// Grab the item immediately below;
// if it has a parent (which should be above us),
// use that parent as the proposed group.
func groupFromChildBelow(_ item: SidebarListItem,
                         _ items: SidebarListItems,
                         movedItemChildrenCount: Int,
                         excludedGroups: ExcludedGroups) -> ProposedGroup? {

    //    log("groupFromChildBelow: item: \(item)")

    let movedItemIndex = item.itemIndex(items)
    let entireIndex = movedItemIndex + movedItemChildrenCount

    // must look at the index of the first item BELOW THE ENTIRE BEING-MOVED-ITEM-LIST
    let indexBelow: Int = entireIndex + 1

    guard let itemBelow = items[safeIndex: indexBelow] else {
        //        log("groupFromChildBelow: no itemBelow")
        return nil
    }

    guard let parentOfItemBelow = itemBelow.parentId else {
        //        log("groupFromChildBelow: no parent on itemBelow")
        return nil
    }

    let itemsAbove = getItemsAbove(item, items)

    guard let parentItemAbove = itemsAbove.first(where: { $0.id == parentOfItemBelow }) else {
        //        log("groupFromChildBelow: could not find parent above")
        return nil
    }

    let proposedParent = parentItemAbove.id
    let proposedIndentation = parentItemAbove.indentationLevel.inc().toXLocation

    // we'll use the indentation level of the parent + 1
    return ProposedGroup(parentId: proposedParent,
                         xIndentation: proposedIndentation)
}

func getItemsBelow(_ item: SidebarListItem, _ items: SidebarListItems) -> SidebarListItems {
    let movedItemIndex = item.itemIndex(items)
    // eg if movedItem's index is 5,
    // then items below have indices 6, 7, 8, ...
    return items.filter { $0.itemIndex(items) > movedItemIndex }
}

func getItemsAbove(_ item: SidebarListItem, _ items: SidebarListItems) -> SidebarListItems {
    let movedItemIndex = item.itemIndex(items)
    // eg if movedItem's index is 5,
    // then items above have indices 4, 3, 2, ...
    return items.filter { $0.itemIndex(items) < movedItemIndex }
}

func findDeepestParent(_ item: SidebarListItem, // the moved-item
                       _ masterList: SidebarListItemsCoordinator,
                       cursorDrag: SidebarCursorHorizontalDrag) -> ProposedGroup? {

    var proposed: ProposedGroup?

    //    log("findDeepestParent: item.id: \(item.id)")
    //    log("findDeepestParent: item.location.x: \(item.location.x)")
    //    log("findDeepestParent: cursorDrag: \(cursorDrag)")

    let items = masterList.items
    let excludedGroups = masterList.excludedGroups

    let itemLocationX = cursorDrag.x

    for itemAbove in getItemsAbove(item, items) {
        //        log("findDeepestParent: itemAbove.id: \(itemAbove.id)")
        //        log("findDeepestParent: itemAbove.location.x: \(itemAbove.location.x)")

        // Is this dragged item east of the above item?
        // Must be >, not >=, since = is for certain top level cases.
        if itemLocationX > itemAbove.location.x {
            let itemAboveHasChildren = hasChildren(itemAbove.id, masterList)

            // if the itemAbove us itself a parent,
            // then we want to put our being-dragged-item into that itemAbove's child list;
            // and NOT use that itemAbove's own parent as our group
            if itemAboveHasChildren,
               !excludedGroups[itemAbove.id].isDefined,
               itemAbove.isGroup {
                //                log("found itemAbove that has children; will make being-dragged-item")

                // make sure it's not a closed group that we're proposing!

                proposed = ProposedGroup(parentId: itemAbove.id,
                                         xIndentation: itemAbove.indentationLevel.inc().toXLocation)
            }

            // this can't quite be right --
            // eg we can find an item above us that has its own parent,
            // we'd wrongly put the being-dragged-item into

            else if let itemAboveParentId = itemAbove.parentId,
                    !excludedGroups[itemAboveParentId].isDefined {
                //                log("found itemAbove that is part of a group whose parent id is: \(itemAbove.parentId)")
                proposed = ProposedGroup(
                    parentId: itemAboveParentId,
                    xIndentation: itemAbove.location.x)
            }

            // if the item above is NOT itself part of a group,
            // we'll just use the item above now as its parent
            else if !excludedGroups[itemAbove.id].isDefined,
                    item.isGroup {
                //                log("found itemAbove without parent")
                proposed = ProposedGroup(
                    parentId: itemAbove.id,
                    xIndentation: IndentationLevel(1).toXLocation)
                // ^^^ if item has no parent ie is top level,
                // then need this indentation to be at least one level
            }
            //            log("findDeepestParent: found proposed: \(proposed)")
            //            log("findDeepestParent: ... for itemAbove: \(itemAbove.id)")
        } else {
            //            log("\(item.id) was not at/east of itemAbove \(itemAbove.id)")
        }
    }
    //    log("findDeepestParent: final proposed: \(String(describing: proposed))")
    return proposed
}

// if we're blocked by a top level item,
// then we ourselves must become a top level item
func blockedByTopLevelItemImmediatelyAbove(_ item: SidebarListItem,
                                           _ items: SidebarListItems) -> Bool {

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

func proposeGroup(_ item: SidebarListItem, // the moved-item
                  _ masterList: SidebarListItemsCoordinator,
                  _ draggedAlongCount: Int,
                  cursorDrag: SidebarCursorHorizontalDrag) -> ProposedGroup? {

    let items = masterList.items

    //    log("proposeGroup: will try to propose group for item: \(item.id)")

    // GENERAL RULE:
    var proposed = findDeepestParent(item,
                                     masterList,
                                     cursorDrag: cursorDrag)

    // Exceptions:

    // Does the item have a non-parent top-level it immediately above it?
    // if so, that blocks group proposal
    if blockedByTopLevelItemImmediatelyAbove(item, items) {
        //        log("blocked by non-parent top-level item above")
        proposed = nil
    }

    if let groupDueToChildBelow = groupFromChildBelow(
        item,
        items,
        movedItemChildrenCount: draggedAlongCount,
        excludedGroups: masterList.excludedGroups) {

        //        log("found group \(groupDueToChildBelow.parentId) from child below")

        //        proposed = groupDueToChildBelow

        // if our drag is east of the proposed-from-below's indentation level,
        // and we already found a proposed group from 'deepest parent',
        // then don't use proposed-from-below.
        let keepProposed = (groupDueToChildBelow.indentationLevel.toXLocation < cursorDrag.x) && proposed.isDefined

        if !keepProposed {
            //            log("will use group from child below")
            proposed = groupDueToChildBelow
        }
    }

    //    log("proposeGroup: returning: \(String(describing: proposed))")
    return proposed
}

func updateSidebarListItem(_ item: SidebarListItem,
                           _ items: SidebarListItems) -> SidebarListItems {
    let index = item.itemIndex(items)
    var items = items
    items[index] = item
    return items
}

// used only during on drag;
func updatePositionsHelper(_ item: SidebarListItem,
                           _ items: SidebarListItems,
                           _ indicesToMove: [Int],
                           _ translation: CGSize,
                           draggedAlong: SidebarListItemIdSet) -> (SidebarListItems,
                                                                   [Int],
                                                                   SidebarListItemIdSet) {

    //    print("updatePositionsHelper called")

    var item = item
    var items = items
    var indicesToMove = indicesToMove
    var draggedAlong = draggedAlong

    // always update the item's position first:
    item.location = updateYPosition(
        translation: translation,
        location: item.previousLocation)

    let index: Int = items.firstIndex { $0.id == item.id }!
    items[index] = item
    indicesToMove.append(index)

    items.forEach { childItem in
        if let parentId = childItem.parentId,
           parentId == item.id,
           // don't update the item again, since you already did that
           childItem.id != item.id {
            //            let (newItems, newIndices) = updatePositionsHelper(
            draggedAlong.insert(childItem.id)

            let (newItems, newIndices, updatedDraggedAlong) = updatePositionsHelper(
                childItem,
                items,
                indicesToMove,
                translation,
                draggedAlong: draggedAlong)

            for newItem in newItems {
                let i = items.firstIndex { $0.id == newItem.id }!
                items[i] = newItem
            }
            indicesToMove = newIndices
            draggedAlong = draggedAlong.union(updatedDraggedAlong)
        }
    }

    return (items, indicesToMove, draggedAlong)
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
        //        print("diff: \(diff)")

        // movedIndices is never going to be empty!
        // it always has at least a single item
        if movedIndices.isEmpty {
            //            calculatedIndex = calculatedIndex + diff
            calculatedIndex += diff
            //            print("empty movedIndices: calculatedIndex is now: \(calculatedIndex)")
        } else {
            let maxMovedIndex = movedIndices.max()!
            //            print("maxMovedIndex: \(maxMovedIndex)")
            calculatedIndex = maxMovedIndex + diff
            //            print("nonEmpty movedIndices: calculatedIndex is now: \(calculatedIndex)")
        }

        if calculatedIndex > maxIndex {
            //            print("calculatedIndex was too large, will use max index instead")
            calculatedIndex = maxIndex
        }
        return calculatedIndex

    } else {
        //        print("Will NOT adjust moveTo index")
        return calculatedIndex
    }
}

func maybeMoveIndices(originalItemId: SidebarListItemId,
                      _ items: SidebarListItems,
                      indicesMoved: [Int],
                      to: Int,
                      originalIndex: Int) -> SidebarListItems {

    var items = items

    if to != originalIndex {

        let finalOffset = to > originalIndex ? to + 1 : to

        items.move(fromOffsets: IndexSet(indicesMoved),
                   toOffset: finalOffset)

        items = setYPositionByIndices(
            originalItemId: originalItemId,
            items,
            isDragEnded: false)
        return items
    } else {
        return items
    }
}
