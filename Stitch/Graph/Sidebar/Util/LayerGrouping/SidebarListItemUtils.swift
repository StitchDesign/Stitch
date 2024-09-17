//
//  SidebarListItemUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import OrderedCollections

// the total height of the view, ie including padding etc.
//let CUSTOM_LIST_ITEM_VIEW_HEIGHT: Int = 44

// 28 is colored background; but need 4 padding?
//let CUSTOM_LIST_ITEM_VIEW_HEIGHT: Int = 28
//let CUSTOM_LIST_ITEM_VIEW_HEIGHT: Int = 32
let CUSTOM_LIST_ITEM_VIEW_HEIGHT: Int = Int(SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)

// Per Figma, 12 pixels to east
// (During DragTest dev was `VIEW_HEIGHT / 2`)
//let CUSTOM_LIST_ITEM_INDENTATION_LEVEL: Int = 12
//let CUSTOM_LIST_ITEM_INDENTATION_LEVEL: Int = 20
let CUSTOM_LIST_ITEM_INDENTATION_LEVEL: Int = 24

extension SidebarListItem {
    static var fakeSidebarListItem: Self {
        SidebarListItem.init(
            id: .init(NodeId.fakeNodeId),
            layer: .init("Fake title"),
            location: .zero,
            isGroup: false)
    }
}

func asGroupIdSet(groups: SidebarGroupsDict) -> LayerIdSet {
    groups.reduce(LayerIdSet()) { (acc: LayerIdSet, kv: (key: LayerNodeId, value: LayerIdList)) in
        acc.union([kv.key] + kv.value)
    }
}

func asSidebarItems(groups: SidebarGroupsDict,
                    layerNodes: LayerNodesForSidebarDict) -> SidebarItems {

//    log("asSidebarItems: groups: \(groups)")
    // DEBUG: this fn recevies
    if layerNodes.isEmpty {
        log("DEBUG: asSidebarItems: layer nodes in renderState were likely empty due to creation of custom debug appState.")
        return []
    }

    // the "top level" ie non-nested sidebar items;
    // but note that any of these top level sidebars could themselves contain
    // sidebar items of their own.
    var topLevelSidebarItems = SidebarItems()
    // better?: get all ids associated with groups, whether as key or child, as a SET
    // and if a layer node's id appears in that set, then it's not a 'simple case'

    // any layer node that is itself a group or is a child of a group
    let groupIds: LayerIdSet = asGroupIdSet(groups: groups)
    //    log("asSidebarItems: groupIds: \(groupIds)")

    var handledNodes = LayerIdSet()

    //    let maxAttempts = 500
    let maxAttempts = 200
    var attempts = 0

    while handledNodes.count != layerNodes.count {

        // TO STOP US FROM FREEZING
        attempts += 1
        if attempts >= maxAttempts {
            // log("asSidebarItems: failed to generate new sidebar items")
            #if DEV_DEBUG
             log("asSidebarItems: handledNodes: \(handledNodes)")
             log("asSidebarItems: layerNodes: \(layerNodes)")
            //            fatalError()
            return []
            #endif
            return []
        }

        layerNodes.forEach { (id: LayerNodeId, node: LayerNodeForSidebar) in
            // log("asSidebarItems: on layer node: \(node.displayTitle) ... \(id)")
            //            let id = LayerNodeId(id) // update layerNodes dict to contain

            // if node already handled, then skip
            if handledNodes.contains(id) {
                // log("asSidebarItems: already handled id: \(id)")
            }

            // simple case: layer node is
            // - not a group layer node and
            // - not in any group's children
            else if !groupIds.contains(id) {
                //
                // log("asSidebarItems: simple case: id: \(id)")
                topLevelSidebarItems.append(
                    SidebarItem(layerName: node.displayTitle.toLayerNodeTitle,
                                layerNodeId: id))

                handledNodes.insert(id)
            }

            // more complex case: layer is group itself or is a child in a group
            else {
                // log("asSidebarItems: complex case: id: \(id)")
                let xs = asSidebarItemsHelper(
                    node,
                    groups,
                    layerNodes,
                    handledNodes: handledNodes
                )
                topLevelSidebarItems += xs.0
                // add the handled nodes to current handled nodes
                handledNodes = handledNodes.union(xs.1)
            }
        }
    }

//    log("asSidebarItems: topLevelSidebarItems: \(topLevelSidebarItems)")
//    log("asSidebarItems: topLevelSidebarItems.count: \(topLevelSidebarItems.count)")
    return topLevelSidebarItems
}

func asSidebarItemsHelper(_ node: LayerNodeForSidebar, //  layer node whose .layer == .group
                          _ groups: SidebarGroupsDict,
                          _ layerNodes: LayerNodesForSidebarDict, // ALL layer nodes
                          handledNodes: LayerIdSet) -> (SidebarItems, LayerIdSet) {

    var items = SidebarItems()
    var handledNodes: LayerIdSet = handledNodes
    //    log("asSidebarItemsHelper: groups: \(groups)")
    //    log("asSidebarItemsHelper: node id: \(node.id)")
    //    log("asSidebarItemsHelper: handledNodes: \(handledNodes)")

    // if the passed-in node is a child in a group node,
    // rather than a group node itself,
    // that's okay; we just return empty list for now;
    // we'll eventually handle the passed-in node in some group

    // is this also supposed to be: "and node.layerNodeId" is not a group?
    guard let children: LayerIdList = groups[node.id]
    else {
        //        log("asSidebarItemsHelper: node.id \(node.id) is not itself a group node")
        // ie don't yet the node.id to handled-nodes, since it's not handled yet
        return (items, handledNodes)
    }

    // if this current node.id is group and a child in some other group,
    // AND the other group has NOT YET been handled already,
    // we want to return an empty list;
    if groups.contains(where: { (key: LayerNodeId, value: LayerIdList) in
        // this node.id is a child of some other group
        value.contains(node.id)
            // and this other group has not yet been handled
            && !handledNodes.contains(key)
    }) {
        // log("asSidebarItemsHelper: node.id \(node.id) is part of some other group that has not yet been handled")
        return (items, handledNodes)
    }
    // ^^ MAYBE WE'RE HITTING THE ISSUE HERE?
    // ^^ BUT THIS

    for childId in children {
        guard let childNode: LayerNodeForSidebar = layerNodes[childId] else {
            // Only hit once, on sidebar which may have bad data
            log("asSidebarItemsHelper: no layer-node-for-sidebar for childId \(childId)")
            continue
        }

        // if child node is not a group...
        if childNode.layer != .group {
            //            log("asSidebarItemsHelper: regular: childId: \(childId)")
            items += [
                SidebarItem(layerName: childNode.displayTitle.toLayerNodeTitle,
                            layerNodeId: childId)
            ]
            // we've now officially handled this childid
            handledNodes.insert(childId)
        }

        // if child node IS a group layer node
        else {
            //            log("asSidebarItemsHelper: group: childId: \(childId)")
            handledNodes.insert(node.id)

            let ys = asSidebarItemsHelper(childNode,
                                          groups,
                                          layerNodes,
                                          handledNodes: handledNodes)

            //            log("asSidebarItemsHelper ys.0.count: \(ys.0.count)")
            //            log("asSidebarItemsHelper ys.1: \(ys.1)")
            items += ys.0
            // if we turned a group layer child node into another list of items,
            // then we've 'handled' that child node
            handledNodes.insert(childId)

            // whatever other nodes we 'handled' during that process,
            // we also add to our handled nodes
            handledNodes = handledNodes.union(ys.1)
        }
    }

    // add a sidebar item for the group itself
    let result = [SidebarItem(
                    layerName: node.displayTitle.toLayerNodeTitle,
                    layerNodeId: node.id,
                    groupInfo: GroupInfo(groupdId: node.id,
                                         elements: items))
    ]

    // add the node id itself to handled nodes, if we successfully handled it
    handledNodes.insert(node.id)

    //    log("asSidebarItemsHelper: END: handledNodes: \(handledNodes)")

    return (result, handledNodes)
}

func sidebarListItemsFromSidebarItems(_ sidebarItems: SidebarItems,
                                      // which items are currently open
                                      expanded: LayerIdSet) -> SidebarListItemsCoordinator {

    var currentHighestIndex = -1
    var items = SidebarListItems()

    // this isn't correct?
    var collapsed = CollapsedGroups()
    var excluded = ExcludedGroups()

    sidebarItems.forEach { sidebarItem in
        // log("sidebarListItemsFromSidebarItems: on sidebarItem: \(sidebarItem)")

        let (newIndex, newItems, _, newExcluded, newCollapsed) = sidebarListItemsFromSidebarItemsHelper(
            sidebarItem,
            currentHighestIndex,
            parentId: nil, // nil when at top level
            nestingLevel: 0, // 0 when at top
            expanded: expanded,
            excluded: excluded,
            collapsed: collapsed)

        currentHighestIndex = newIndex
        items += newItems

        excluded.merge(newExcluded) { (items1: SidebarListItems, items2: SidebarListItems) in
            mergeDictChildren(items1, items2)
        }
        collapsed = collapsed.union(newCollapsed)
    }

    return SidebarListItemsCoordinator(items, excluded, collapsed)
}

func sidebarListItemsFromSidebarItemsHelper(_ sidebarItem: SidebarItem,
                                            _ currentHighestIndex: Int,
                                            parentId: SidebarListItemId?,
                                            nestingLevel: Int,
                                            expanded: LayerIdSet,
                                            excluded: ExcludedGroups,
                                            collapsed: CollapsedGroups) -> (Int,
                                                                            SidebarListItems,
                                                                            Int,
                                                                            ExcludedGroups,
                                                                            CollapsedGroups) {

    var currentHighestIndex = currentHighestIndex
    var items = SidebarListItems()
    var nestingLevel = nestingLevel
    var excluded = excluded
    var collapsed = collapsed

    currentHighestIndex += 1

    let hasChildren = sidebarItem.groupInfo.isDefined

    var item = SidebarListItem(
        id: SidebarListItemId(sidebarItem.id.id),
        layer: sidebarItem.layerName,
        //        location: CGPoint(x: (CUSTOM_LIST_ITEM_VIEW_HEIGHT / 2) * nestingLevel,
        location: CGPoint(x: CUSTOM_LIST_ITEM_INDENTATION_LEVEL * nestingLevel,
                          y: CUSTOM_LIST_ITEM_VIEW_HEIGHT * currentHighestIndex),
        parentId: parentId,
        isGroup: hasChildren)

    // If item is a collapsed parent, then add it to excluded groups but not `items`.

    // TODO: find a better way to handle this such that we don't need `expanded` anymore...
    if item.isGroup && expanded.doesNotContain(item.id.asLayerNodeId) {
        // log("itemsFromSidebarHelper: excluding a non-expanded parent: \(item.id)")
        collapsed.insert(item.id)
        excluded = appendToExcludedGroup(for: item.id, [], excluded)
    }

    // If this is a child whose parent is collapsed,
    // then add this child to excluded groups,
    // and remove from it `items` list.
    if let parentId = item.parentId,
       collapsed.contains(parentId) {
        // log("itemsFromSidebarHelper: excluding a child of a non-expanded parent: \(item.id)")
        // decrement currentHighestIndex because we won't actually show this item
        currentHighestIndex -= 1
        //        item.location = CGPoint(x: (CUSTOM_LIST_ITEM_VIEW_HEIGHT / 2) * nestingLevel,
        item.location = CGPoint(x: CUSTOM_LIST_ITEM_INDENTATION_LEVEL * nestingLevel,
                                y: CUSTOM_LIST_ITEM_VIEW_HEIGHT * currentHighestIndex)
        excluded = appendToExcludedGroup(for: parentId, [item], excluded)
    } else {
        // log("itemsFromSidebarHelper: adding item id: \(item.id)")
        items.append(item)
    }

    if !hasChildren {
        // log("No children, so returning")
        return (currentHighestIndex, items, nestingLevel, excluded, collapsed)
    }

    // if we're about to go down another level,
    // increment the nesting
    if hasChildren {
        nestingLevel += 1
    }

    // log("itemsFromSidebarHelper: had children: sidebarItem.children: \(sidebarItem.children)")
    
    sidebarItem.children.forEach { sidebarItemChild in
        // log("itemsFromSidebarHelper: on child: sidebarItemChild: \(sidebarItemChild)")
        let (newIndex,
             newItems,
             newLevel,
             newExcluded,
             newCollapsed) = sidebarListItemsFromSidebarItemsHelper(sidebarItemChild,
                                                                    currentHighestIndex,
                                                                    parentId: item.id,
                                                                    nestingLevel: nestingLevel,
                                                                    expanded: expanded,
                                                                    excluded: excluded,
                                                                    collapsed: collapsed)

        currentHighestIndex = newIndex
        items += newItems
        nestingLevel = newLevel
        excluded.merge(newExcluded) { (items1: SidebarListItems, items2: SidebarListItems) in
            mergeDictChildren(items1, items2)
        }

        collapsed = collapsed.union(newCollapsed)

    }
    // While looking through the children,
    // we had an increased nesting level,
    // but when we're done, we move back out,
    // and so must decrement the nesting level.
    nestingLevel -= 1

    return (currentHighestIndex, items, nestingLevel, excluded, collapsed)
}

// used for reduce-like operations on ExcludedGroups
func mergeDictChildren(_ items1: SidebarListItems,
                       _ items2: SidebarListItems) -> SidebarListItems {
    OrderedSet<SidebarListItem>(items1 + items2).elements
}

extension String {
    var toLayerNodeTitle: LayerNodeTitle {
        LayerNodeTitle(self)
    }
}

extension SidebarItem {
    func toSidebarLayerData() -> SidebarLayerData {
        let item = self
        
//        SidebarLayerData(id: item.id.asNodeId,
//                         children: item.groupInfo?.elements?.map({ $0.toSidebarLayerData() }))
        
        if let children = item.groupInfo?.elements {
            return SidebarLayerData(id: item.id.asNodeId,
                                    children: children.map { $0.toSidebarLayerData() })
        } else {
            return SidebarLayerData(id: item.id.asNodeId)
        }
    }
}
