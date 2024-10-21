//
//  SidebarListItemSelectionActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension GraphState {
    @MainActor
    func allShareSameParent(selections: Set<NodeId>) -> Bool {
        guard let parentId = selections.first else {
            return false
        }
        return selections.allSatisfy { id in
            // does `id` have a parent, and is that parent the same as the random parent?
            self.getNodeViewModel(id)?.layerNode?.layerGroupId == parentId
        }
    }

    // selections can only be grouped if they ALL belong to EXACT SAME PARENT (or top level)
    // ASSUMES NON-EMPTY
}

extension ProjectSidebarObservable {
    func secondarilySelectAllChildren(id: Self.ItemID,
                                      groups: SidebarGroupsDict) {
        
        let acc = self.selectionState
        
        // add to acc
        self.addExclusivelyToSecondary(id)
        
        // recur on children
        if let children = groups[id] {
            children.forEach { (child: Self.ItemID) in
                self.secondarilySelectAllChildren(
                    id: child,
                    groups: groups)
            }
        }
    }
    
    // children to deselect
    @MainActor
    func getDescendantsIds(id: Self.ItemID) -> Set<ItemID> {
//                                  groups: SidebarGroupsDict,
//                                  acc: Set<ItemID>) -> Set<ItemId> {
        guard let children = self.createdOrderedEncodedData().get(id)?.children else { return .init() }
        return children.flatMap { $0.allElementIds }
            .toSet
        
        //
//        var acc = acc
//        acc.insert(id)
//        
//        // recur on children
//        if let children = groups[id] {
//            children.forEach { (child: Self.ItemID) in
//                acc = acc.union(getDescendantsIds(id: child,
//                                                  groups: groups,
//                                                  acc: acc))
//            }
//        }
//        
//        return acc
    }
    
    func removeFromSelections(_ id: Self.ItemID) {
        self.selectionState.primary.remove(id)
        self.selectionState.secondary.remove(id)
    }
    
    func addExclusivelyToPrimary(_ id: Self.ItemID) {
        // add to primary
        self.selectionState.primary.insert(id)
        
        // ... and remove from secondary (migt not be present?):
        self.selectionState.secondary.remove(id)
    }
    
    func addExclusivelyToSecondary(_ id: Self.ItemID) {
        let selection = self.selectionState
        selection.secondary.insert(id)
        selection.primary.remove(id)
    }
    
    
    static func allShareSameParent(_ selections: Self.SidebarSelectionState.SidebarSelections,
                                   groups: Self.SidebarGroupsDict) -> Bool {
        
        if let firstSelection = selections.first,
           let parent = findGroupLayerParentForLayerNode(firstSelection, groups) {
            return selections.allSatisfy { id in
                // does `id` have a parent, and is that parent the same as the random parent?
                findGroupLayerParentForLayerNode(id, groups).map { $0 == parent } ?? false
            }
        } else {
            return false // ie no parent
        }
    }
    
    // selections can only be grouped if they ALL belong to EXACT SAME PARENT (or top level)
    // ASSUMES NON-EMPTY
    @MainActor
    func canBeGrouped() -> Bool {
        let selections = self.selectionState.primary
        let groups = self.getSidebarGroupsDict()
        
        // items are on same level if they are all top level
        let allTopLevel = selections.allSatisfy {
            !Self.findGroupLayerParentForLayerNode($0, groups).isDefined
        }
        
        // ... or if they all have same parent
        let allSameParent = Self.allShareSameParent(selections, groups: groups)
        
        return allTopLevel || allSameParent
    }
    
    // Can ungroup selections just if:
    // 1. at least one group is 100% selected, and
    // 2. no non-group items are 100% selected
    @MainActor func canUngroup() -> Bool {
        !groupPrimarySelections().isEmpty &&
        nonGroupPrimarySelections().isEmpty
    }
    
    // 100% selected items that ARE groups
    @MainActor func groupPrimarySelections() -> [Self.ItemID] {
        self.selectionState.primary.filter { selected in
            if let item = self.items.get(selected) {
                return item.isGroup
            }
            return false
        }
    }
    
    // 100% selected items that are NOT groups
    @MainActor func nonGroupPrimarySelections() -> Set<Self.ItemID> {
        self.selectionState.primary.filter { selected in
            if let item = self.items.get(selected) {
                return !item.isGroup
            }
            return false
        }
    }
    
    func canDuplicate() -> Bool {
        !self.selectionState.primary.isEmpty
    }
}

extension GraphState {
    // When an individual sidebar item is deleted via the swipe menu
    @MainActor
    func sidebarItemDeleted(itemId: SidebarListItemId) {
        self.deleteNode(id: itemId)
                
        self.updateGraphData()
        self.encodeProjectInBackground()
    }
}
