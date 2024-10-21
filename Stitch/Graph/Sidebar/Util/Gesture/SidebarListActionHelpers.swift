//
//  CustomListActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/15/22.
//

import Foundation
import SwiftUI

let SIDEBAR_LIST_ITEM_MAX_Z_INDEX: ZIndex = 9999
let SIDEBAR_LIST_ITEM_MIN_Z_INDEX: ZIndex = 0

extension ProjectSidebarObservable {
    // When dragging: set actively-dragged and dragged-along items' z-indices to be high
    // When drag ended: set all items z-indices = 0
//    @MainActor
//    func updateZIndices(zIndex: ZIndex) {
//        self.items.forEach {
//            item.zIndex = zIndex
//        }
//    }
    
//    @MainActor
//    func updateAllZIndices(itemId: Self.ItemID,
//                           draggedAlong: Set<Self.ItemID>) {
//        self.items.forEach {
//            if ($0.id == itemId) || draggedAlong.contains($0.id) {
//                $0.zIndex = SIDEBAR_LIST_ITEM_MAX_Z_INDEX
//            }
//        }
//    }
//    
//    @MainActor
//    func setItemsInGroupOrTopLevel(item: Self.ItemViewModel,
//                                   otherSelections: Set<Self.ItemID>,
//                                   draggedAlong: Set<Self.ItemID>) {
//        
//        // set all dragged items' z-indices to max
////        self.updateAllZIndices(
////            itemId: item.id,
////            draggedAlong:
////                draggedAlong)
//        
//        // Propose a group based on the dragged item (in Stack case, will be Stack's top item)
//        let proposed = self.proposeGroup(item)
//        
////        let beingDragged = SidebarDraggedItem(current: item.id,
////                                              draggedAlong: draggedAlong)
//        
//        if let proposed = proposed {
//            self.moveSidebarListItemIntoGroup(item,
//                                              otherSelections: otherSelections,
//                                              draggedAlong: draggedAlong,
//                                              proposed)
//        }
//        
//        // if no proposed group, then we moved item to top level:
//        // 1. reset done-dragging item's x to `0`
//        // 2. set item's parent to nil
//        else {
//            log("setItemsInGroupOrTopLevel: no proposed group; will snap to top level")
////            self.items.remove(item.id)
//            fatalErrorIfDebug("TODO: come back here as logic likely doesn't work")
//            self.items.append(item)
//
////            self.moveSidebarListItemToTopLevel(item,
////                                               otherSelections: otherSelections,
////                                               draggedAlong: draggedAlong)
//        }
//        
////        self.currentItemDragged = result.beingDragged
////        self.proposedGroup = result.proposed
////        self.cursorDrag = result.cursorDrag
//    }
    
    // We've moved the item up or down (along with its children);
    // did we move it enough to have a new index placement for it?
//    @MainActor
//    func calculateNewIndexOnDrag(item: Self.ItemViewModel,
//                                 otherSelections: Set<ItemID>,
////                                 draggedAlong: Set<ItemID>,
//                                 movingDown: Bool) -> Int {
////                                 originalItemIndex: Int,
////                                 movedIndices: [Int]) -> Int {
//        
////        let maxMovedToIndex = self.items.count - 1
//        
////        self.getMaxMovedToIndex(
////            item: item,
////            otherSelections: otherSelections,
////            draggedAlong: draggedAlong)
//        
//        let calculatedIndex = self.getMovedtoIndex(
//            item: item,
////            maxIndex: maxMovedToIndex,
//            movingDown: movingDown)
//        
//        // log("calculateNewIndexOnDrag: originalItemIndex: \(originalItemIndex)")
//        // log("calculateNewIndexOnDrag: calculatedIndex was: \(calculatedIndex)")
//        
//        // Is this really correct?
//        // i.e. shouldn't this be the `maxMovedToIndex` ?
//        // er, this is like "absolute max index", looking at ALL items in the list
////        let maxIndex = items.count - 1
//        
//        // Can't this be combined with something else?
////        calculatedIndex = adjustMoveToIndex(
////            calculatedIndex: calculatedIndex,
////            originalItemIndex: originalItemIndex,
////            movedIndices: movedIndices,
////            maxIndex: maxIndex)
//        
//        // log("calculateNewIndexOnDrag: calculatedIndex is now: \(calculatedIndex)")
//        
//        return calculatedIndex
//    }
    
//    // the highest index we can have moved an item to;
//    // based on item count but with special considerations
//    // for whether we're dragging a group.
//    func getMaxMovedToIndex(item: Self.ItemViewModel,
//                            otherSelections: Set<ItemID>,
//                            draggedAlong: Set<ItemID>) -> Int {
//        
//        var maxIndex = self.items.count - 1
//        
//        // log("getMaxMovedToIndex: maxIndex was \(maxIndex)")
//        
//        // Presumably we don't actually need to trck whether the `dragged item` is a group or not; `draggedAlong` already represents the children that will be dragged along
//        let itemsWithoutDraggedAlongOrOtherSelections = items.filter { x in !draggedAlong.contains(x.id) && !otherSelections.contains(x.id) }
//        
//        // log("getMaxMovedToIndex: itemsWithoutDraggedAlongOrOtherSelections \(itemsWithoutDraggedAlongOrOtherSelections.map(\.id))")
//        
//        maxIndex = itemsWithoutDraggedAlongOrOtherSelections.count - 1
//        // log("getMaxMovedToIndex: maxIndex is now \(maxIndex)")
//        
//        return maxIndex
//    }
    
    @MainActor
    static func getMovedtoIndex(dragY: CGFloat,
                                movingDown: Bool,
                                flattenedItems: [Self.ItemViewModel]) -> Int? {
        
        let maxIndex = flattenedItems.count - 1
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
            ? dragY > CGFloat(threshold)
            : dragY < CGFloat(threshold)
            
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
        
        return nil
//        // if didn't find anything, return the original index?
//        let k = flattenedItems.firstIndex { $0.id == item.id }!
//        // log("getMovedtoIndex: k: \(k)")
//        return k
    }
}
