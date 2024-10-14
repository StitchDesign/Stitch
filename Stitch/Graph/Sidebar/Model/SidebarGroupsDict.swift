//
//  SidebarGroupsDict.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit

extension ProjectSidebarObservable {
    @MainActor
    func getSidebarGroupsDict() -> Self.SidebarGroupsDict {
        let orderedSidebarItems = self.createdOrderedEncodedData()
        var partialResult = Self.SidebarGroupsDict()
        
        // just assume top level for now; non-nested etc.
        orderedSidebarItems.forEach { (orderedSidebarItem : Self.EncodedItemData) in
            
            partialResult = Self.addToSidebarGroupsDict(
                orderedSidebarItem: orderedSidebarItem,
                partialResult: partialResult)
        }
        
        return partialResult
    }
    
    static func addToSidebarGroupsDict(orderedSidebarItem: Self.EncodedItemData,
                                       partialResult: Self.SidebarGroupsDict) -> Self.SidebarGroupsDict {
        
        var partialResult = partialResult
        
        let isGroupLayer = orderedSidebarItem.children.isDefined
        
        // careful: need to know whether the ordered sidebar item is for a group or not; can't just rely on children-list being present or not
        if isGroupLayer,
           let children = orderedSidebarItem.children {
            
            // Add a result for this OSI itself
            partialResult[orderedSidebarItem.id] = children.map(\.id)
            
            // Then handle its children
            children.forEach { childOSI in
                partialResult = addToSidebarGroupsDict(
                    orderedSidebarItem: childOSI,
                    partialResult: partialResult)
            }
        }
        
        return partialResult
    }
}

