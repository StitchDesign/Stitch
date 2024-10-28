//
//  SidebarSelectionState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import StitchSchemaKit

//struct InspectorFocusedData<ItemID: Hashable> {
//    
////    // Focused = what we see focused in the inspector
////    var focused = Set<ItemID>()
////    
////    // Actively Selected = what we see focused in inspector + what user has recently tapped on
////    var activelySelected = Set<ItemID>()
//
//    // Updated by regular or command click, but not shick click (with some exceptions)
//    var lastFocusedLayer: ItemID? = nil
//    
//    // Inserts into both focused and activelySelected layer id sets
////    func insert(_ layer: ItemID) -> Self {
////        self.insert(.init([layer]))
////    }
//    
//    func insert(_ layers: Set<ItemID>) -> Self {
//        var data = self
//        data.focused = data.focused.union(layers)
//        data.activelySelected = data.activelySelected.union(layers)
//        return data
//    }
//}

//@Observable
//final class SidebarSelectionObserver<SidebarViewModel: ProjectSidebarObservable> {
//    typealias ItemID = SidebarViewModel.ItemID
//    typealias SidebarSelections = Set<ItemID>
//    
//    var haveDuplicated: Bool = false
//    var optionDragInProgress: Bool = false
//    
//    // non-empty only during active layer drag (multi-drag only?)
//    //    var implicitlyDragged = SidebarListItemIdSet()
//    
//    // Layers focused in the inspector
//    //    var inspectorFocusedLayers = InspectorFocusedData<ItemID>() //LayerIdSet()
//    
//    // items selected because directly clicked
//    var primary = SidebarSelections()
//    
//    // items selected because eg their parent was selected
//    //    var secondary = SidebarSelections()
//    
//    var lastFocused: ItemID?
//    
//    weak var sidebarDelegate: SidebarViewModel?
//}

typealias SidebarSelectionObserver = ProjectSidebarObservable

extension ProjectSidebarObservable {
//    func getSelectionStatus(_ id: ItemID) -> SidebarListItemSelectionStatus {
//
//        if self.primary.contains(id) {
//            return .primary
//        } else if self.secondary.contains(id) {
//            return .secondary
//        } else {
//            return .none
//        }
//
//    }
    
    var all: Set<Self.ItemID> {
        self.items.flattenedSelectedItems(from: self.primary)
            .map { $0.id }
            .toSet
    }
    
    func isSelected(_ id: ItemID) -> Bool {
        all.contains(id)
    }

    func resetEditModeSelections() {
        self.primary = .init()
//        self.secondary = SidebarSelections()
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
