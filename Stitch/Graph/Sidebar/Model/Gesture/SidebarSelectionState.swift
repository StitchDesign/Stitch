//
//  SidebarSelectionState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import StitchSchemaKit

typealias SidebarSelectionObserver = ProjectSidebarObservable

extension ProjectSidebarObservable {
    var all: Set<Self.ItemID> {
        self.items.getAllSelectedItems(from: self.selectionState.primary)
    }
    
    func resetEditModeSelections() {
        // DO NOT 'focus the sidebar' here; resetting primary selections is NOT the same thing as tapping or dragging a layer
//        self.graphDelegate?.graphUI.isSidebarFocused = true
        
        self.primary = .init()
    }
}

extension Array where Element: SidebarItemSwipable {
    func getAllSelectedItems(from selections: Set<Element.ID>) -> Set<Element.ID> {
        self.reduce(into: Set<Element.ID>()) { result, item in
            if selections.contains(item.id) {
                let selectionsHere = [item.id] + (item.children?.flattenedItems.map(\.id) ?? [])
                result = result.union(selectionsHere)
            } else if let recursiveChildrenSelections = item.children?.getAllSelectedItems(from: selections) {
                // Recursively check children if they exist
                result = result.union(recursiveChildrenSelections)
            }
        }
        .toSet
    }
}
