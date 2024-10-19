//
//  SidebarSelectionState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import StitchSchemaKit
import OrderedCollections

typealias OrderedLayerNodeIdSet = OrderedSet<LayerNodeId>
//typealias SidebarSelections = LayerIdSet
//typealias NonEmptySidebarSelections = NonEmptyLayerIdSet

//extension LayerIdSet {
//    var asSidebarListItemIdSet: SidebarListItemIdSet {
//        self.map(\.asItemId).toSet
//    }
//}

struct InspectorFocusedData<ItemID: Hashable> {
    
    // Focused = what we see focused in the inspector
    var focused = Set<ItemID>()
    
    // Actively Selected = what we see focused in inspector + what user has recently tapped on
    var activelySelected = Set<ItemID>()

    // Updated by regular or command click, but not shick click (with some exceptions)
    var lastFocusedLayer: ItemID? = nil
    
    // Inserts into both focused and activelySelected layer id sets
    func insert(_ layer: ItemID) -> Self {
        self.insert(.init([layer]))
    }
    
    func insert(_ layers: Set<ItemID>) -> Self {
        var data = self
        data.focused = data.focused.union(layers)
        data.activelySelected = data.activelySelected.union(layers)
        return data
    }
}

//extension SidebarSelections {
//    var nonEmptyPrimary: NonEmptySidebarSelections? {
//        if self.isEmpty {
//            return nil
//        } else {
//            return NES(self)!
//        }
//    }
//}

@Observable
final class SidebarSelectionObserver<ItemID: Hashable> {
    typealias SidebarSelections = Set<ItemID>
    
    //    var isEditMode: Bool = false
    
    // avoid this?
    var madeStack: Bool = false
    
    var haveDuplicated: Bool = false
    var optionDragInProgress: Bool = false
    
    // non-empty only during active layer drag (multi-drag only?)
    //    var implicitlyDragged = SidebarListItemIdSet()
    
    // Layers focused in the inspector
    var inspectorFocusedLayers = InspectorFocusedData<ItemID>() //LayerIdSet()
    
    // items selected because directly clicked
    var primary = SidebarSelections()
    
    // items selected because eg their parent was selected
    var secondary = SidebarSelections()
}

extension SidebarSelectionObserver {
    func getSelectionStatus(_ id: ItemID) -> SidebarListItemSelectionStatus {

        if self.primary.contains(id) {
            return .primary
        } else if self.secondary.contains(id) {
            return .secondary
        } else {
            return .none
        }

    }
    
    var all: SidebarSelections {
        primary.union(secondary)
    }

//    var nonEmptyPrimary: SidebarSelections? {
//        self.primary.nonEmptyPrimary
//    }
    
    func isSelected(_ id: ItemID) -> Bool {
        all.contains(id)
    }

    func resetEditModeSelections() {
        self.primary = SidebarSelections()
        self.secondary = SidebarSelections()
    }

    // better
//    func combine(other: Self) {
//        self.primary = self.primary.union(other.primary)
//        self.secondary = self.secondary.union(other.secondary)
//    }
}
