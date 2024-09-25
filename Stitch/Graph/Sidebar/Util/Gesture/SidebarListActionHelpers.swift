//
//  CustomListActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/15/22.
//

import Foundation
import SwiftUI


// When dragging: set actively-dragged and dragged-along items' z-indices to be high
// When drag ended: set all items z-indices = 0
@MainActor
func updateZIndices(_ items: SidebarListItems,
                    zIndex: ZIndex) -> SidebarListItems {
    items.map {
        var item = $0
        item.zIndex = zIndex
        return item
    }
}

let SIDEBAR_LIST_ITEM_MAX_Z_INDEX: ZIndex = 9999
let SIDEBAR_LIST_ITEM_MIN_Z_INDEX: ZIndex = 0

@MainActor
func updateAllZIndices(items: SidebarListItems,
                       itemId: SidebarListItemId,
                       draggedAlong: SidebarListItemIdSet) -> SidebarListItems {

    var items = items

    let updatedItems = updateZIndices(
        items.filter {
            ($0.id == itemId) || draggedAlong.contains($0.id)
        },
        zIndex: SIDEBAR_LIST_ITEM_MAX_Z_INDEX)

    for updatedItem in updatedItems {
        items = updateSidebarListItem(updatedItem, items)
    }

    return items
}

@MainActor
func setItemsInGroupOrTopLevel(item: SidebarListItem,
                               masterList: MasterList,
                               draggedAlong: SidebarListItemIdSet,
                               cursorDrag: SidebarCursorHorizontalDrag) -> SidebarListItemDraggedResult {

    var masterList = masterList

    // set all dragged items' z-indices to max
    masterList.items = updateAllZIndices(
        items: masterList.items, itemId:
            item.id, draggedAlong:
                draggedAlong)

    let proposed = proposeGroup(
        item,
        masterList,
        draggedAlong.count,
        cursorDrag: cursorDrag)

    let beingDragged = SidebarDraggedItem(current: item.id,
                                          draggedAlong: draggedAlong)

    //    log("setItemsInGroupOrTopLevel: beingDragged: \(beingDragged)")

    // TODO: SEPT 24: revisit this once we're working in non-flat UIs
    if let proposed = proposed {
        //        log("setItemsInGroupOrTopLevel: had proposed: \(proposed)")
        masterList.items = moveSidebarListItemIntoGroup(item,
                                                        masterList.items,
                                                        draggedAlong: draggedAlong,
                                                        proposed)
    }

    // if no proposed group, then we moved item to top level:
    // 1. reset done-dragging item's x to `0`
    // 2. set item's parent to nil
    else {
        //        log("setItemsInGroupOrTopLevel: no proposed group; will snap to top level")
        masterList.items = moveSidebarListItemToTopLevel(item,
                                                         masterList.items,
                                                         draggedAlong: draggedAlong)
    }

    return SidebarListItemDraggedResult(masterList: masterList,
                                        proposed: proposed,
                                        beingDragged: beingDragged,
                                        cursorDrag: cursorDrag)
}

// We've moved the item up or down (along with its children);
// did we move it enough to have a new index placement for it?
@MainActor
func calculateNewIndexOnDrag(item: SidebarListItem,
                             items: SidebarListItems,
                             otherSelections: SidebarListItemIdSet,
                             draggedAlong: SidebarListItemIdSet,
                             movingDown: Bool,
                             originalItemIndex: Int,
                             movedIndices: [Int]) -> Int {

    
    
    let maxMovedToIndex = getMaxMovedToIndex(
        item: item,
        items: items,
        otherSelections: otherSelections,
        draggedAlong: draggedAlong)

    var calculatedIndex = getMovedtoIndex(
        item: item,
        items: items,
        otherSelections: otherSelections,
        draggedAlong: draggedAlong,
        maxIndex: maxMovedToIndex,
        movingDown: movingDown)

    print("calculateNewIndexOnDrag: originalItemIndex: \(originalItemIndex)")
    print("calculateNewIndexOnDrag: calculatedIndex was: \(calculatedIndex)")

    // Is this really correct?
    let maxIndex = items.count - 1

    // Can't this be combined with something else?
    calculatedIndex = adjustMoveToIndex(
        calculatedIndex: calculatedIndex,
        originalItemIndex: originalItemIndex,
        movedIndices: movedIndices,
        maxIndex: maxIndex)

    print("calculateNewIndexOnDrag: calculatedIndex is now: \(calculatedIndex)")

    return calculatedIndex
}


// TODO: SEPT 24: probably need to update this to also excluded the other-dragged layers
// this is probably necessary because the children haven't had their indices changed yet?
// highest index = last item in the list THAT IS NOT ACITVELY BEING DRAGGED (so excluded


// the highest index we can have moved an item to;
// based on item count but with special considerations
// for whether we're dragging a group.
func getMaxMovedToIndex(item: SidebarListItem,
                        items: SidebarListItems,
                        otherSelections: SidebarListItemIdSet,
                        draggedAlong: SidebarListItemIdSet) -> Int {

    var maxIndex = items.count - 1

    log("getMaxMovedToIndex: maxIndex was \(maxIndex)")
    
    // special case: when moving a group,
    // ignore the children we're dragging along
//    if item.isGroup {
    //        let itemsWithoutDraggedAlong = items.filter { x in !draggedAlong.contains(x.id) }
    
    // Presumably we don't actually need to trck whether the `dragged item` is a group or not; `draggedAlong` already represents the children that will be dragged along
    let itemsWithoutDraggedAlongOrOtherSelections = items.filter { x in !draggedAlong.contains(x.id) && !otherSelections.contains(x.id) }
    
    log("getMaxMovedToIndex: itemsWithoutDraggedAlongOrOtherSelections \(itemsWithoutDraggedAlongOrOtherSelections.map(\.id))")
    
    maxIndex = itemsWithoutDraggedAlongOrOtherSelections.count - 1
    log("getMaxMovedToIndex: maxIndex is now \(maxIndex)")
    
    //    }
    return maxIndex
}

func getMovedtoIndex(item: SidebarListItem,
                     items: SidebarListItems,
                     otherSelections: SidebarListItemIdSet,
                     draggedAlong: SidebarListItemIdSet,
                     maxIndex: Int,
                     movingDown: Bool) -> Int {

    // The below should be unnecessary, since we already determined the maxIndex
    
//    var maxIndex = items.count - 1
//
//    // special case:
//    // if we moved a parent to the end of the items (minus parents' own children),
//    // then don't adjust-by-indices while dragging.
//    if item.isGroup {
//        let itemsWithoutDraggedAlong = items.filter { x in !draggedAlong.contains(x.id) && !otherSelections.contains(x.id) }
//        maxIndex = itemsWithoutDraggedAlong.count - 1
//    }

    let maxY = maxIndex * CUSTOM_LIST_ITEM_VIEW_HEIGHT

    var range = (0...maxY)
        .filter { $0.isMultiple(of: CUSTOM_LIST_ITEM_VIEW_HEIGHT / 2) }

    range.append(range.last! + CUSTOM_LIST_ITEM_VIEW_HEIGHT/2 )

    if movingDown {
        range = range.reversed()
    }

    // try to find the highest threshold we (our item's location.y) satisfy
    for threshold in range {

        // for moving up, want to find the first threshold we UNDERSHOOT
        // where range is (0, 50, 150, ..., 250)

        // for moving down, want to find the first treshold we OVERSHOOT
        // where range is (250, ..., 150, 50, 0)

        let foundThreshold = movingDown
            ? item.location.y > CGFloat(threshold)
            : item.location.y < CGFloat(threshold)

        if foundThreshold {
            var k = (CGFloat(threshold)/CGFloat(CUSTOM_LIST_ITEM_VIEW_HEIGHT))
            // if we're moving the item down,
            // then we'll want to round up the threshold
            if movingDown {
                k.round(.up)
            } else {
                k.round(.down)
            }
            // NEVER RETURN AN INDEX HIGHER THAN MAX-INDEX
            let ki = Int(k)
            if ki > maxIndex {
                print("getMovedtoIndex: maxIndex: \(maxIndex)")
                return maxIndex
            } else {
                print("getMovedtoIndex: ki: \(ki)")
                return ki
            }
        }
    }

    // if didn't find anything, return the original index?
    let k = items.firstIndex { $0.id == item.id }!
    print("getMovedtoIndex: k: \(k)")
    return k
}
