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

/*
 
 */
struct InspectorFocusedLayers: Codable, Equatable, Hashable {
    
    // Focused = what we see focused in the inspector
    var focused = LayerIdSet()
    
    // Actively Selected = what we see focused in inspector + what user has recently tapped on
    var activelySelected = LayerIdSet()
}

extension SidebarSelections {
    var nonEmptyPrimary: NonEmptySidebarSelections? {
        if self.isEmpty {
            return nil
        } else {
            return NES(self)!
        }
    }
}

// if a group is selected,
struct SidebarSelectionState: Codable, Equatable, Hashable {
    
    var isEditMode: Bool = false
        
    // Layers focused in the inspector
    var inspectorFocusedLayers = InspectorFocusedLayers() //LayerIdSet()
    
    // items selected because directly clicked
    var primary = SidebarSelections()

    // items selected because eg their parent was selected
    var secondary = SidebarSelections()
    
    var all: SidebarSelections {
        primary.union(secondary)
    }

    var nonEmptyPrimary: NonEmptySidebarSelections? {
        self.primary.nonEmptyPrimary
    }

    func isSelected(_ id: LayerNodeId) -> Bool {
        all.contains(id)
    }

    mutating func resetEditModeSelections() {
        self.primary = SidebarSelections()
        self.secondary = SidebarSelections()
    }

    // better
    mutating func combine(other: SidebarSelectionState) {
        self.primary = self.primary.union(other.primary)
        self.secondary = self.secondary.union(other.secondary)
    }
}
