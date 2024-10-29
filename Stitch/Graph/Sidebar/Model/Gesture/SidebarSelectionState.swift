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
        let secondarySelected = self.items.flattenedSelectedItems(from: self.primary)
            .map { $0.id }
            .toSet
        
        return self.primary.union(secondarySelected)
    }
    
    func resetEditModeSelections() {
        self.graphDelegate?.graphUI.isSidebarFocused = true
        self.primary = .init()
    }
}

extension Array where Element: SidebarItemSwipable {
    func flattenedSelectedItems(from selectedIds: Set<Element.ID>) -> [Element] {
        self.flatMap { item -> [Element] in
            guard selectedIds.contains(item.id) else { return [] }
            
            guard item.isExpandedInSidebar ?? false,
                  let children = item.children else { return [item] }
            
            return [item] + children.flattenedSelectedItems(from: selectedIds)
        }
    }
}
