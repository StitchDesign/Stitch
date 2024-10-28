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

extension SidebarItemSwipable {    
    /// Recursively removes self + children from selection state.
    func removeFromSelections() {
        guard let sidebar = self.sidebarDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        sidebar.selectionState.primary.remove(self.id)
        
        self.children?.forEach { child in
            child.removeFromSelections()
        }
    }
}

extension ProjectSidebarObservable {
    
    // children to deselect
    @MainActor
    func getDescendantsIds(id: Self.ItemID) -> Set<ItemID> {
        guard let children = self.createdOrderedEncodedData().get(id)?.children else { return .init() }
        return children.flatMap { $0.allElementIds }
            .toSet
    }
    
    func addExclusivelyToPrimary(_ id: Self.ItemID) {
        // add to primary
        self.selectionState.primary.insert(id)
    }
    
    
    func allShareSameParent(_ selections: Set<Self.ItemID>) -> Bool {
        
        if let firstSelection = selections.first,
           let firstSelectionItem = self.items.get(firstSelection),
           let parent = firstSelectionItem.parentDelegate?.id {
            return selections.allSatisfy { id in
                // does `id` have a parent, and is that parent the same as the random parent?
                let item = self.items.get(id)
                return item?.parentDelegate?.id == parent
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
        
        // items are on same level if they are all top level
        let allTopLevel = selections.allSatisfy { selectionId in
            self.items.get(selectionId)?.parentDelegate == nil
        }
        
        // ... or if they all have same parent
        let allSameParent = self.allShareSameParent(selections)
        
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
