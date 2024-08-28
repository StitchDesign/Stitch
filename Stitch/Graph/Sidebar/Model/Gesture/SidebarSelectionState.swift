//
//  SidebarSelectionState.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import StitchSchemaKit
import OrderedCollections

typealias OrderedLayerNodeIdSet = OrderedSet<LayerNodeId>
typealias SidebarSelections = LayerIdSet
typealias NonEmptySidebarSelections = NonEmptyLayerIdSet

// if a group is selected,
struct SidebarSelectionState: Codable, Equatable, Hashable {
    
    // For inspector, not layer-group creation etc.
    var nonEditModeSelections = OrderedLayerNodeIdSet()
    
    // items selected because directly clicked
    var primary = SidebarSelections()

    // items selected because eg their parent was selected
    var secondary = SidebarSelections()
    
    var all: SidebarSelections {
        primary.union(secondary)
    }

    var nonEmptyPrimary: NonEmptySidebarSelections? {
        if primary.isEmpty {
            return nil
        } else {
            return NES(primary)!
        }
    }

    func isSelected(_ id: LayerNodeId) -> Bool {
        all.contains(id)
    }

    mutating func resetSelections() {
        self.primary = SidebarSelections()
        self.secondary = SidebarSelections()
    }

    // better
    mutating func combine(other: SidebarSelectionState) {
        self.primary = self.primary.union(other.primary)
        self.secondary = self.secondary.union(other.secondary)
    }
}
