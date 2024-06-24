//
//  SidebarGroupsDict.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import OrderedCollections

typealias SidebarGroupsDict = OrderedDictionary<LayerNodeId, LayerIdList>

extension SidebarGroupsDict {
    
    static func fromOrderedSidebarItems(_ orderedSidebarItems: OrderedSidebarLayers) -> SidebarGroupsDict {
        
        var partialResult = SidebarGroupsDict()
        
        // just assume top level for now; non-nested etc.
        orderedSidebarItems.forEach { (orderedSidebarItem : SidebarLayerData) in

            partialResult = addToSidebarGroupsDict(
                orderedSidebarItem: orderedSidebarItem,
                partialResult: partialResult)
        }
        
        return partialResult
    }
}

func addToSidebarGroupsDict(orderedSidebarItem: SidebarLayerData,
                            partialResult: SidebarGroupsDict) -> SidebarGroupsDict {
    
    var partialResult = partialResult
    
    let isGroupLayer = orderedSidebarItem.children.isDefined
    
    // careful: need to know whether the ordered sidebar item is for a group or not; can't just rely on children-list being present or not
    if isGroupLayer,
        let children = orderedSidebarItem.children {
        
        // Add a result for this OSI itself
        partialResult[orderedSidebarItem.id.asLayerNodeId] = children.map(\.id.asLayerNodeId)
        
        // Then handle its children
        children.forEach { childOSI in
            partialResult = addToSidebarGroupsDict(
                orderedSidebarItem: childOSI,
                partialResult: partialResult)
        }
    }
    
    return partialResult
}

extension GraphState {
    func getSidebarGroupsDict() -> SidebarGroupsDict {
        .fromOrderedSidebarItems(self.orderedSidebarLayers)
    }
}
