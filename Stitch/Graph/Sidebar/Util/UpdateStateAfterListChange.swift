//
//  UpdateStateAfterListChange.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// MasterList
typealias MasterList = SidebarListItemsCoordinator

// e.g. we dragged a sidebar item, and we need to now update the view models (ordered-sidebar-items and layer nodes dict) based on the new SidebarListState
// should make this function smaller; not take all of graphState but return specific values etc.
func _updateStateAfterListChange(updatedList: SidebarListState,
                                 expanded: LayerIdSet,
                                 graphState: GraphState) {

    let orderedSidebarLayers: SidebarLayerList = graphState.orderedSidebarLayers
    let layerNodes: NodesViewModelDict = graphState.layerNodes
    
    let layerNodeSidebarState: LayerNodesForSidebarDict = .fromLayerNodesDict(
        nodes: layerNodes,
        orderedSidebarItems: orderedSidebarLayers)

    // put the update sidebar-list-state in graph state
    graphState.sidebarListState = updatedList
    
    let groups = graphState.getSidebarGroupsDict()
    
    // we have an updated sidebarListState;
    // we need to turn that into an update of the view models: (ordered-sidebar-items, layer nodes dict)
    
    let oldDeps = SidebarDeps(
        layerNodes: layerNodeSidebarState,
        groups: groups,
        expandedItems: expanded)
    
    // ie list state -> redux state
    let updatedDeps: SidebarDeps = sidebarListItemsToSidebarDeps(
        oldDeps,
        updatedList.masterList)

    let newGroups: SidebarGroupsDict = updatedDeps.groups
    let newLayerNodesForSidebar: LayerNodesForSidebarDict = updatedDeps.layerNodes
    
    
    // two steps:
    // 1. update layer nodes' layerGroupId; some layer node may now be part of a different group, or not in a group at alll anymore
    // 2. update ordered-sidebar-items
    
    // step 1:
    graphState.layerNodes.values.forEach { node in
//        log("_updateStateAfterListChange: updated layer group parent id for node.id: \(node.id)")
//
        // TODO: Can skip this check and just assume layerNodes has a `LayerNodeViewModel` ?
        if node.layerNode.isDefined {
            
            // find parent for this layer node, based on new sidebar-groups-dict
            let groupLayerParent = findGroupLayerParentForLayerNode(node.id.asLayerNodeId,
                                                                    newGroups)
            
            
            node.layerNode?.layerGroupId = groupLayerParent?.id
        }
//        else {
//            log("_updateStateAfterListChange: wasn't a layer node?")
//        }
    }
        
    // better?: use logic from `GraphSchema.getOrderedLayers` to create SidebarItems from layerNodesForSidebarDict and sidebarGroups, and then turn those SidebarItems into OSIs
    let newSidebarItems = asSidebarItems(groups: newGroups,
                                         layerNodes: newLayerNodesForSidebar)
        
    let newOrderedSidebarLayers: OrderedSidebarLayers = newSidebarItems.map {  $0.toSidebarLayerData()
    }
    
    graphState.orderedSidebarLayers = newOrderedSidebarLayers
}

// creates new expandedItem
// creates new (LayerNodesForSidebarDict, SidebarGroups, ExpandedItems)
func sidebarListItemsToSidebarDeps(_ sidebar: SidebarDeps,
                                   _ masterList: SidebarListItemsCoordinator) -> SidebarDeps {

    let expanded = expandedItemsFromCollapsedGroups(
        sidebar.layerNodes,
        masterList.collapsedGroups)

    // log("sidebarListItemsToSidebarDeps: expanded: \(expanded)")

    var updatedNodes = LayerNodesForSidebarDict() // LayerNodesDict()
    var updatedGroups = SidebarGroupsDict()

    // `items` will be in order; and so will children in excluded groups
    let allItems = masterList.items + flattenExcludedGroups(masterList.excludedGroups)

    // Rebuild the ordered-dict of layer-nodes in same order of sidebarListItems.
    allItems.forEach { (item: SidebarListItem) in

        //        log("sidebarListItemsToSidebarDeps: item.id: \(item.id)")

        guard let node: LayerNodeForSidebar = sidebar.layerNodes[item.id.asLayerNodeId] else {
            // we had a rect item that had no corresponding layer node!
            fatalError()
        }

        // Always add the layer node to the rebuilt layer-nodes-dict

        // Additionally: if the item is a child of the group,
        // add it to the sidebar groups dict
        if let parentId = item.parentId {
            // log("sidebarListItemsToSidebarDeps: item \(item.id) had parent id: \(parentId)")
            // log("sidebarListItemsToSidebarDeps: updatedGroups was: \(updatedGroups)")

            updatedGroups = appendToSidebarGroup(
                for: parentId.asLayerNodeId,
                [item.id.asLayerNodeId],
                updatedGroups)

            // log("sidebarListItemsToSidebarDeps: updatedGroups is now: \(updatedGroups)")
        }

        // Always add [] when we encounter the group itself;
        // ensures we create a `sidebarGroups` entry for every group,
        // even if group is empty.
        if item.isGroup {
            // log("sidebarListItemsToSidebarDeps: item \(item.id) was a parent")
            // log("sidebarListItemsToSidebarDeps: updatedGroups was: \(updatedGroups)")
            updatedGroups = appendToSidebarGroup(
                for: item.id.asLayerNodeId,
                [],
                updatedGroups)
            // log("sidebarListItemsToSidebarDeps: updatedGroups is now: \(updatedGroups)")
        }

        // presumably appends to end?
        // ie `insertingAt: currentIndex + 1`
        updatedNodes.updateValue(node, forKey: node.id)
    }

    var sidebar = sidebar
    sidebar.layerNodes = updatedNodes
    sidebar.groups = updatedGroups
    sidebar.expandedItems = expanded

    return sidebar
}

func appendToSidebarGroup(for key: LayerNodeId,
                          _ newChildren: [LayerNodeId],
                          _ groups: SidebarGroupsDict) -> SidebarGroupsDict {

    var groups = groups
    var existing: LayerIdList = groups[key] ?? []

    //    for child in newChildren {
    //        if existing.contains(child) {
    //            log("appendToSidebarGroup: child \(child) is already in existing: \(existing)")
    //        }
    //    }

    existing.append(contentsOf: newChildren)
    groups.updateValue(existing, forKey: key)
    return groups
}
