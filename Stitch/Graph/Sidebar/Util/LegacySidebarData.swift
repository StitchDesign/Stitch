//
//  LegacySidebarData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/7/24.
//

import Foundation
import StitchSchemaKit

func flattenExcludedGroups(_ excluded: ExcludedGroups) -> SidebarListItems {
    excluded.flatMap { (_: SidebarListItemId, value: SidebarListItems) in
        value
    }
}


// Any group that is not collapsed is considered 'expanded'
func expandedItemsFromCollapsedGroups(_ layerNodes: LayerNodesForSidebarDict,
                                      _ collapsedGroups: SidebarListItemIdSet) -> LayerIdSet {
    var acc = LayerIdSet()

    layerNodes.values.forEach { node in
        let id = SidebarListItemId(node.id.id)
        if node.layer == .group && !collapsedGroups.contains(id) {
            //            log("expandedItemsFromCollapsedGroups: will add node.layerNodeId to current expanded")
            acc.insert(node.id)
        }
    }

    return acc
}


/*
 Simplifying assumptions:
 - all groups are open (i.e. none are collapsed; so can leave
 */
// e.g. we just added a layer node, so need to produce a new
//func getMasterListFrom(existingMasterList: MasterList, // for existing collapsed groups etc.
//                       layerNodes: LayerNodesDict,
//                       orderedSidebarItems: SidebarLayerList) -> MasterList {

//func getMasterListFrom(layerNodes: LayerNodesDict,
//                       orderedSidebarItems: SidebarLayerList) -> MasterList {

// Really, we return not just the master list but the SidebarListState which contains `current` etc.
func getMasterListFrom(layerNodes: NodesViewModelDict,
                       expanded: LayerIdSet,
                       orderedSidebarItems: SidebarLayerList) -> SidebarListState {
        
    let masterList = _updateListAfterStateChange(
        orderedSidebarLayers: orderedSidebarItems,
        expanded: expanded,
        layerNodes: layerNodes)
    
    var state = SidebarListState()
    state.masterList = masterList
    return state
}

extension LayerNodesForSidebarDict {
    // assumes `nodes` is layer nodes only
    static func fromLayerNodesDict(nodes: NodesViewModelDict,
                                   orderedSidebarItems: OrderedSidebarLayers) -> LayerNodesForSidebarDict {
        
        orderedSidebarItems.reduce(into: LayerNodesForSidebarDict()) { partialResult, osi in
            partialResult = addLayerNodeForSidebarToDict(
                nodes: nodes,
                orderedSidebarItem: osi,
                partialResult: partialResult)
        }
    }
}

func addLayerNodeForSidebarToDict(nodes: NodesViewModelDict,
                                  orderedSidebarItem: SidebarLayerData,
                                  partialResult: LayerNodesForSidebarDict) -> LayerNodesForSidebarDict {
    
    //    log("addLayerNodeForSidebarToDict called for orderedSidebarItem: \(orderedSidebarItem)")
    
    var partialResult = partialResult
    
    if let node = nodes.get(orderedSidebarItem.id),
       let layerNode = node.layerNode {
        
        partialResult[node.id.asLayerNodeId] = LayerNodeForSidebar(
            id: node.id.asLayerNodeId,
            layer: layerNode.layer,
            displayTitle: node.getDisplayTitle())
        
        orderedSidebarItem.children?.forEach({ childOSI in
            partialResult = addLayerNodeForSidebarToDict(
                nodes: nodes,
                orderedSidebarItem: childOSI,
                partialResult: partialResult)
        })
        
        
    } else {
        // e.g. the layer node was deleted
        log("LayerNodesForSidebarDict: fromLayerNodesDict: did not have node for OrderedSidebarItem \(orderedSidebarItem.id)")
    }
  
    return partialResult
}

func _updateListAfterStateChange(orderedSidebarLayers: SidebarLayerList,
                                 expanded: LayerIdSet,
                                 layerNodes: NodesViewModelDict) -> MasterList {


    let layerNodesForSidebar: LayerNodesForSidebarDict = .fromLayerNodesDict(
        nodes: layerNodes,
        orderedSidebarItems: orderedSidebarLayers)
        
    let groups: SidebarGroupsDict = .fromOrderedSidebarItems(
        orderedSidebarLayers)
        
    let items: SidebarItems = asSidebarItems(
        groups: groups,
        layerNodes: layerNodesForSidebar)
        
    let masterList = sidebarListItemsFromSidebarItems(
        items,
        // i.e. which groups are open
        expanded: expanded)
    
    return masterList
}
