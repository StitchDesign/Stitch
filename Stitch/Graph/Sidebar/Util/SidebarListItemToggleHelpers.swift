//
//  _SidebarListItemToggleHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

//
//  CustomListToggleHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/15/22.
//

import Foundation
import SwiftUI

// functions for opening and closing groups

extension ProjectSidebarObservable {
    // ONLY USEFUL FOR NON-DRAGGING CASES
    // ie when closing or opening a group
//    @MainActor
//    func getDescendants(_ parentItem: Self.ItemViewModel) -> [Self.ItemViewModel] {
//        
//        var descendants = [Self.ItemViewModel]()
//        
//        for item in self.getItemsBelow(parentItem) {
//            //        log("itemBelow: \(item.id), \(item.location.x)")
//            // if you encounter an item at or west of the parentXLocation,
//            // then you've finished the parent's nested groups
//            if item.location.x <= parentItem.location.x {
//                //            log("getDescendants: exiting early")
//                //            log("getDescendants: early exit: descendants: \(descendants)")
//                return descendants
//            } else {
//                descendants.append(item)
//            }
//        }
//        //    log("getDescendants: returning: descendants: \(descendants)")
//        return descendants
//    }
    
//    // if "parent" does not have an iimte
//    // Better?: `!getDescendents.isEmpty`
//    func hasOpenChildren(_ item: Self.ItemViewModel) -> Bool {
//        
//        let parentIndex = item.itemIndex(self.items)
//        let nextChildIndex = parentIndex + 1
//        
//        if let child = self.items[safeIndex: nextChildIndex],
//           let childParent = child.parentId,
//           childParent == item.id {
//            return true
//        }
//        return false
//    }
//    
    // only called if parent has children
//    @MainActor
//    func hideChildren(closedParentId: Self.ItemID) {
//        
//        // TODO: just mark a single property and update views
//        
//        
//        
//        guard let closedParent = self.retrieveItem(closedParentId) else {
//            fatalErrorIfDebug("Could not retrieve item")
//            return
//        }
//        
//        // if there are no descendants, then we're basically done
//        
//        // all the items below this parent, with indentation > parent's
//        let descendants = self.getDescendants(closedParent)
//        
//        // starting: immediate parent will have closed parent's id
//        var currentParent = closedParentId
//        
//        // starting: immediate child of parent will have parent's indentation level + 1
//        var currentDeepestIndentation = closedParent.indentationLevel.inc()
//        
//        for descendant in descendants {
//            //        log("on descendant: \(descendant)")
//            
//            // if we ever have a descendant at, or west of, the closedParent,
//            // then we made a mistake!
//            // MARK: this doesn't seem to matter
////            if descendant.indentationLevel.value <= closedParent.indentationLevel.value {
////                fatalErrorIfDebug()
////            }
//            
//            if descendant.indentationLevel == currentDeepestIndentation {
//                self.appendToExcludedGroup(
//                    for: currentParent,
//                    descendant)
//            }
//            // we either increased or decreased in indentation
//            else {
//                // if we changed indentation levels (whether east or west),
//                // we should have a new parent
//                currentParent = descendant.parentId!
//                
//                // ie we went deeper (farther east)
//                if descendant.indentationLevel.value > currentDeepestIndentation.value {
//                    // log("went east")
//                    currentDeepestIndentation = currentDeepestIndentation.inc()
//                }
//                // ie. we backed up (went one level west)
//                // ie. descendant.indentationLevel.value < currentDeepestIndentation.value
//                else {
//                    // log("went west")
//                    currentDeepestIndentation = currentDeepestIndentation.dec()
//                }
//                
//                // set the descendant AFTER we've updated the parent
//                self.appendToExcludedGroup(
//                    for: currentParent,
//                    descendant)
//            }
//        }
//        
//        // finally, remove descendants from items list
//        let descendentsIdSet: Set<Self.ItemID> = Set(descendants.map(\.id))
//        self.items.removeAll { descendentsIdSet.contains($0.id) }
//    }
    
//    func appendToExcludedGroup(for key: Self.ItemID,
//                               _ newItems: [Self.ItemViewModel],
//                               _ excludedGroups: Self.ExcludedGroups) {
//        //    log("appendToExcludedGroup called")
//        
//        var existing = excludedGroups[key] ?? []
//        existing.append(contentsOf: newItems)
//        
//        var excludedGroups = excludedGroups
//        excludedGroups.updateValue(existing, forKey: key)
//        
//        self.excludedGroups = excludedGroups
//    }
//    
    // retrieve children
    // nil = parentId had no
    // non-nil = returning children, plus removing the parentId entry from ExcludedGroups
//    @MainActor
//    func popExcludedChildren(parentId: Self.ItemID) -> [Self.ItemViewModel]? {
//        
//        if let excludedChildren = self.excludedGroups[parentId] {
//            // prevents us from opening any subgroups that weren't already opend
//            if self.collapsedGroups.contains(parentId) {
//                log("this subgroup was closed when it was put away, so will skip it")
//                return nil
//            }
//            
//            return excludedChildren
//        }
//        return nil
//    }
    
    func getChildren(for parentId: Self.ItemID) -> [Self.ItemViewModel] {
        self.items.filter {
            $0.parentId == parentId
        }
    }
}

//extension SidebarItemSwipable {
//    func setOpenedChildHeight(height: CGFloat) {
//        // set height only; preserve indentation
//        self.location = CGPoint(x: self.location.x, y: height)
//        self.previousLocation = self.location
//    }
//}

extension ProjectSidebarObservable {
//    @MainActor
//    func unhideChildrenHelper(item: Self.ItemViewModel, // item that could be a parent or not
//                              currentHighestIndex: Int, // starts: opened parent's index
//                              currentHighestHeight: CGFloat, // starts: opened parent's height
//                              isRoot: Bool) -> (Int, CGFloat) {
//        
//        var currentHighestIndex = currentHighestIndex
//        var currentHighestHeight = currentHighestHeight
//        
//        // insert item
//        if !isRoot {
//            let (updatedHighestIndex,
//                 updatedHighestHeight) = self.insertUnhiddenItem(item: item,
//                                                                 currentHighestIndex: currentHighestIndex,
//                                                                 currentHighestHeight: currentHighestHeight)
//            
//            currentHighestIndex = updatedHighestIndex
//            currentHighestHeight = updatedHighestHeight
//        }
//        //    else {
//        //        log("unhideChildrenHelper: had root item \(item.id), so will not add root item again")
//        //    }
//        
//        // does this `item` have children of its own?
//        // if so, recur
//        if item.isCollapsedGroup {
//            // log("unhideChildrenHelper: had children")
//            let excludedChildren = self.getChildren(for: item.id)
//            
//            // excluded children must be handled in IN ORDER
//            for child in excludedChildren {
//                // log("unhideChildrenHelper: on child \(child.id) of item \(item.id)")
//                let (updatedHighestIndex,
//                     updatedHighestHeight) = unhideChildrenHelper(
//                        item: child,
//                        currentHighestIndex: currentHighestIndex,
//                        currentHighestHeight: currentHighestHeight,
//                        isRoot: false)
//                
//                currentHighestIndex = updatedHighestIndex
//                currentHighestHeight = updatedHighestHeight
//            }
//        }
//        //    else {
//        //        log("unhideChildrenHelper: did not have children")
//        //    }
//        
//        return (currentHighestIndex, currentHighestHeight)
//    }
    
//    func insertUnhiddenItem(item: Self.ItemViewModel, // item that could be a parent or not
//                            currentHighestIndex: Int, // starts: opened parent's index
//                            // starts: opened parent's height
//                            currentHighestHeight: CGFloat) -> (Int, CGFloat) {
//        
//        var currentHighestIndex = currentHighestIndex
//        var currentHighestHeight = currentHighestHeight
//        
//        // + 1 so inserted AFTER previous currentHighestIndex
//        currentHighestIndex += 1
//        currentHighestHeight += CGFloat(CUSTOM_LIST_ITEM_VIEW_HEIGHT)
//        
//        item.setOpenedChildHeight(height: currentHighestHeight)
//        self.items.insert(item, at: currentHighestIndex)
//        
//        return (currentHighestIndex, currentHighestHeight)
//    }

//    @MainActor
//    func unhideChildren(openedParent: Self.ItemID,
//                        parentIndex: Int,
//                        parentY: CGFloat) -> Int {
//        
//        // this can actually happen
//        guard self.excludedGroups[openedParent].isDefined else {
//            fatalErrorIfDebug("Attempted to open a parent that did not have excluded children")
//            return parentIndex
//        }
//        
//        // log("unhideChildren: parentIndex: \(parentIndex)")
//        
//        guard let parent = self.retrieveItem(openedParent) else {
//            fatalErrorIfDebug("Could not retrieve item")
//            return parentIndex
//        }
//        
//        // if you start with the parent, you double add it
//        let (lastIndex, _) = self.unhideChildrenHelper(
//            item: parent,
//            currentHighestIndex: parent.itemIndex(self.items),
//            currentHighestHeight: parent.location.y,
//            isRoot: true)
//        
//        return lastIndex
//    }
    
    // all children, closed or open
//    func childrenForParent(parentId: Self.ItemID) -> [Self.ItemViewModel] {
//        self.items.filter { $0.parentId == parentId }
//    }

//    func adjustItemsBelow(_ parentId: Self.ItemID,
//                          _ parentIndex: Int, // parent that was opened or closed
//                          adjustment: CGFloat) { // down = +y; up = -y
//        self.items.forEach { item in
//            // only adjust items below the parent
//            if item.itemIndex(items) > parentIndex,
//               // ... but don't adjust children of the parent,
//               // since their position was already set in `unhideGroups`;
//                // and when hiding a group, there are no children to adjust.
//                item.parentId != parentId {
//
//                // adjust both location and previousLocation
//                item.location = CGPoint(x: item.location.x,
//                                        y: item.location.y + adjustment)
//                item.previousLocation = item.location
//            }
//        }
//    }
    
//    func adjustNonDescendantsBelow(_ lastIndex: Int, // the last item
//                                   adjustment: CGFloat) { // down = +y; up = -y
//        self.items.forEach { item in
//            if item.itemIndex(self.items) > lastIndex {
//                item.location = CGPoint(x: item.location.x,
//                                        y: item.location.y + adjustment)
//                item.previousLocation = item.location
//            }
//        }
//    }

    @MainActor
//    func hasChildren(_ parentId: Self.ItemID) -> Bool {
//        
//        if let x = self.items.first(where: { $0.id == parentId }),
//           x.isGroup {
//            //        log("hasChildren: true because isGroup")
//            return true
//        } else if self.excludedGroups[parentId].isDefined {
//            //        log("hasChildren: true because has entry in excludedGroups")
//            return true
//        } else if !self.childrenForParent(parentId: parentId).isEmpty {
//            //        log("hasChildren: true because has non-empty children in on-screen items")
//            return true
//        } else {
//            //        log("hasChildren: false....")
//            return false
//        }
//    }
    
    func retrieveItem(_ id: Self.ItemID) -> Self.ItemViewModel? {
        self.items.get(id)
    }
}
