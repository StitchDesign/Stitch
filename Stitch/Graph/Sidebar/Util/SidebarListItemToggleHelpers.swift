//
//  _SidebarListItemToggleHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

//
//  CustomListToggleHelpers.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/15/22.
//

import Foundation
import SwiftUI

// functions for opening and closing groups

// ONLY USEFUL FOR NON-DRAGGING CASES
// ie when closing or opening a group
@MainActor
func getDescendants(_ parentItem: SidebarListItem,
                    _ items: SidebarListItems) -> SidebarListItems {

    var descendants = SidebarListItems()

    for item in getItemsBelow(parentItem, items) {
        //        log("itemBelow: \(item.id), \(item.location.x)")
        // if you encounter an item at or west of the parentXLocation,
        // then you've finished the parent's nested groups
        if item.location.x <= parentItem.location.x {
            //            log("getDescendants: exiting early")
            //            log("getDescendants: early exit: descendants: \(descendants)")
            return descendants
        } else {
            descendants.append(item)
        }
    }
    //    log("getDescendants: returning: descendants: \(descendants)")
    return descendants
}

// if "parent" does not have an iimte
// Better?: `!getDescendents.isEmpty`
func hasOpenChildren(_ item: SidebarListItem, _ items: SidebarListItems) -> Bool {

    let parentIndex = item.itemIndex(items)
    let nextChildIndex = parentIndex + 1

    if let child = items[safeIndex: nextChildIndex],
       let childParent = child.parentId,
       childParent == item.id {
        return true
    }
    return false
}

// only called if parent has children
@MainActor
func hideChildren(closedParentId: SidebarListItemId,
                  _ masterList: MasterList) -> MasterList {

    var masterList = masterList

    let closedParent = retrieveItem(closedParentId, masterList.items)

    // if there are no descendants, then we're basically done

    // all the items below this parent, with indentation > parent's
    let descendants = getDescendants(closedParent, masterList.items)

    // starting: immediate parent will have closed parent's id
    var currentParent: SidebarListItemId = closedParentId

    // starting: immediate child of parent will have parent's indentation level + 1
    var currentDeepestIndentation = closedParent.indentationLevel.inc()

    for descendant in descendants {
        //        log("on descendant: \(descendant)")

        // if we ever have a descendant at, or west of, the closedParent,
        // then we made a mistake!
        if descendant.indentationLevel.value <= closedParent.indentationLevel.value {
            fatalError()
        }

        if descendant.indentationLevel == currentDeepestIndentation {
            masterList = masterList.appendToExcludedGroup(
                for: currentParent,
                descendant)
        }
        // we either increased or decreased in indentation
        else {
            // if we changed indentation levels (whether east or west),
            // we should have a new parent
            currentParent = descendant.parentId!

            // ie we went deeper (farther east)
            if descendant.indentationLevel.value > currentDeepestIndentation.value {
                // log("went east")
                currentDeepestIndentation = currentDeepestIndentation.inc()
            }
            // ie. we backed up (went one level west)
            // ie. descendant.indentationLevel.value < currentDeepestIndentation.value
            else {
                // log("went west")
                currentDeepestIndentation = currentDeepestIndentation.dec()
            }

            // set the descendant AFTER we've updated the parent
            masterList = masterList.appendToExcludedGroup(
                for: currentParent,
                descendant)
        }
    }

    // finally, remove descendants from items list
    let descendentsIdSet: Set<SidebarListItemId> = Set(descendants.map(\.id))
    masterList.items.removeAll { descendentsIdSet.contains($0.id) }

    return masterList
}

func appendToExcludedGroup(for key: SidebarListItemId,
                           _ newItems: SidebarListItems,
                           _ excludedGroups: ExcludedGroups) -> ExcludedGroups {
    //    log("appendToExcludedGroup called")

    var existing: SidebarListItems = excludedGroups[key] ?? []
    existing.append(contentsOf: newItems)

    var excludedGroups = excludedGroups
    excludedGroups.updateValue(existing, forKey: key)

    return excludedGroups
}

// retrieve children
// nil = parentId had no
// non-nil = returning children, plus removing the parentId entry from ExcludedGroups
func popExcludedChildren(parentId: SidebarListItemId,
                         _ masterList: MasterList) -> (SidebarListItems, ExcludedGroups)? {

    if let excludedChildren = masterList.excludedGroups[parentId] {

        // prevents us from opening any subgroups that weren't already opend
        if masterList.collapsedGroups.contains(parentId) {
            log("this subgroup was closed when it was put away, so will skip it")
            return nil
        }

        var groups = masterList.excludedGroups
        groups.removeValue(forKey: parentId)
        return (excludedChildren, groups)
    }
    return nil
}

func setOpenedChildHeight(_ item: SidebarListItem,
                          _ height: CGFloat) -> SidebarListItem {
    var item = item
    // set height only; preserve indentation
    item.location = CGPoint(x: item.location.x, y: height)
    item.previousLocation = item.location
    return item
}

func unhideChildrenHelper(item: SidebarListItem, // item that could be a parent or not
                          currentHighestIndex: Int, // starts: opened parent's index
                          currentHighestHeight: CGFloat, // starts: opened parent's height
                          _ masterList: MasterList,
                          isRoot: Bool) -> (MasterList, Int, CGFloat) {

    var masterList = masterList
    var currentHighestIndex = currentHighestIndex
    var currentHighestHeight = currentHighestHeight

    // insert item
    if !isRoot {
        let (updatedMaster,
             updatedHighestIndex,
             updatedHighestHeight) = insertUnhiddenItem(item: item,
                                                        currentHighestIndex: currentHighestIndex,
                                                        currentHighestHeight: currentHighestHeight,
                                                        masterList)

        masterList = updatedMaster
        currentHighestIndex = updatedHighestIndex
        currentHighestHeight = updatedHighestHeight
    } 
    //    else {
    //        log("unhideChildrenHelper: had root item \(item.id), so will not add root item again")
    //    }

    // does this `item` have children of its own?
    // if so, recur
    if let (excludedChildren, updatedGroups) = popExcludedChildren(
        parentId: item.id, masterList) {

        // log("unhideChildrenHelper: had children")

        masterList.excludedGroups = updatedGroups

        // excluded children must be handled in IN ORDER
        for child in excludedChildren {
            // log("unhideChildrenHelper: on child \(child.id) of item \(item.id)")
            let (updatedMaster,
                 updatedHighestIndex,
                 updatedHighestHeight) = unhideChildrenHelper(
                    item: child,
                    currentHighestIndex: currentHighestIndex,
                    currentHighestHeight: currentHighestHeight,
                    masterList,
                    isRoot: false)

            masterList = updatedMaster
            currentHighestIndex = updatedHighestIndex
            currentHighestHeight = updatedHighestHeight
        }
    } 
    //    else {
    //        log("unhideChildrenHelper: did not have children")
    //    }

    return (masterList, currentHighestIndex, currentHighestHeight)
}

func insertUnhiddenItem(item: SidebarListItem, // item that could be a parent or not
                        currentHighestIndex: Int, // starts: opened parent's index
                        currentHighestHeight: CGFloat, // starts: opened parent's height
                        _ masterList: MasterList) -> (MasterList, Int, CGFloat) {

    var item = item
    var currentHighestIndex = currentHighestIndex
    var currentHighestHeight = currentHighestHeight
    var masterList = masterList

    // + 1 so inserted AFTER previous currentHighestIndex
    currentHighestIndex += 1
    currentHighestHeight += CGFloat(CUSTOM_LIST_ITEM_VIEW_HEIGHT)

    item = setOpenedChildHeight(item, currentHighestHeight)
    masterList.items.insert(item, at: currentHighestIndex)

    return (masterList, currentHighestIndex, currentHighestHeight)
}

func unhideChildren(openedParent: SidebarListItemId,
                    parentIndex: Int,
                    parentY: CGFloat,
                    _ masterList: MasterList) -> (MasterList, Int) {

    // this can actually happen
    guard masterList.excludedGroups[openedParent].isDefined else {
        #if DEV || DEV_DEBUG
        log("Attempted to open a parent that did not have excluded children")
        fatalError()
        #endif
        return (masterList, parentIndex) //
    }

    // log("unhideChildren: parentIndex: \(parentIndex)")

    let parent = retrieveItem(openedParent, masterList.items)

    // if you start with the parent, you double add it
    let (updatedMaster, lastIndex, _) = unhideChildrenHelper(
        item: parent,
        currentHighestIndex: parent.itemIndex(masterList.items),
        currentHighestHeight: parent.location.y,
        masterList,
        isRoot: true)

    return (updatedMaster, lastIndex)
}

// all children, closed or open
func childrenForParent(parentId: SidebarListItemId,
                       _ items: SidebarListItems) -> SidebarListItems {
    items.filter { $0.parentId == parentId }
}

func adjustItemsBelow(_ parentId: SidebarListItemId,
                      _ parentIndex: Int, // parent that was opened or closed
                      adjustment: CGFloat, // down = +y; up = -y
                      _ items: SidebarListItems) -> SidebarListItems {

    return items.map { item in
        // only adjust items below the parent
        if item.itemIndex(items) > parentIndex,
           // ... but don't adjust children of the parent,
           // since their position was already set in `unhideGroups`;
           // and when hiding a group, there are no children to adjust.
           item.parentId != parentId {
            var item = item
            // adjust both location and previousLocation
            item.location = CGPoint(x: item.location.x,
                                    y: item.location.y + adjustment)
            item.previousLocation = item.location
            return item
        } else {
            //            print("Will not adjust item \(item.id)")
            return item
        }
    }
}

func adjustNonDescendantsBelow(_ lastIndex: Int, // the last item
                               adjustment: CGFloat, // down = +y; up = -y
                               _ items: SidebarListItems) -> SidebarListItems {

    return items.map { item in
        if item.itemIndex(items) > lastIndex {
            var item = item
            item.location = CGPoint(x: item.location.x,
                                    y: item.location.y + adjustment)
            item.previousLocation = item.location
            return item
        } else {
            return item
        }
    }
}

func retrieveItem(_ id: SidebarListItemId,
                  _ items: SidebarListItems) -> SidebarListItem {
    items.first { $0.id == id }!
}

func hasChildren(_ parentId: SidebarListItemId, _ masterList: MasterList) -> Bool {

    if let x = masterList.items.first(where: { $0.id == parentId }),
       x.isGroup {
        //        log("hasChildren: true because isGroup")
        return true
    } else if masterList.excludedGroups[parentId].isDefined {
        //        log("hasChildren: true because has entry in excludedGroups")
        return true
    } else if !childrenForParent(parentId: parentId, masterList.items).isEmpty {
        //        log("hasChildren: true because has non-empty children in on-screen items")
        return true
    } else {
        //        log("hasChildren: false....")
        return false
    }
}
