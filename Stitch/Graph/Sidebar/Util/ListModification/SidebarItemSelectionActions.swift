//
//  SidebarItemDeselected.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OrderedCollections

// Sidebar layer 'tapped' while not in
struct SidebarItemTapped: GraphEvent {
    
    let id: LayerNodeId
    
    func handle(state: GraphState) {
        let alreadySelected = state.sidebarSelectionState
            .nonEditModeSelections.contains(id)
    
        // TODO: support multiple selections and filter property inspector appropriately
        if alreadySelected {
            state.sidebarSelectionState.nonEditModeSelections = .init()
        } else {
            state.sidebarSelectionState.nonEditModeSelections = .init([id])
        }
        
        // Reset selected row in property sidebar when focused-layers changes
        state.graphUI.propertySidebar.selectedProperty = nil
        
        // TODO: better: allow multiple selections via cmd+click, not single click
//        if alreadySelected {
//            state.sidebarSelectionState.nonEditModeSelections.remove(id)
//        } else {
//            state.sidebarSelectionState.nonEditModeSelections.append(id)
//        }
    }
}

// group or top level
struct SidebarItemSelected: GraphEvent {
    let id: LayerNodeId
    
    func handle(state: GraphState) {

        log("SidebarItemSelected: id: \(id)")
        
        let sidebarGroups = state.getSidebarGroupsDict()

        log("SidebarItemSelected: sidebarGroups: \(sidebarGroups)")
        log("SidebarItemSelected: state.sidebarSelectionState was: \(state.sidebarSelectionState)")
        
        // we selected a group -- so 100% select the group
        // and 80% all the children further down in the street
        if state.getNodeViewModel(id.id)?.kind.getLayer == .group {

            state.sidebarSelectionState = addExclusivelyToPrimary(
                id, state.sidebarSelectionState)

            sidebarGroups[id]?.forEach({ (childId: LayerNodeId) in
                state.sidebarSelectionState = secondarilySelectAllChildren(
                    id: childId,
                    groups: sidebarGroups,
                    acc: state.sidebarSelectionState)
            })
        }

        // if we selected a child of a group,
        // then deselect that parent and all other children,
        // and primarily select the child.
        // ie deselect everything(?), and only select the child.

        // TRICKY: what if eg
        else if let parent = findGroupLayerParentForLayerNode(id, sidebarGroups) {

            // if the parent is currently selected,
            // then deselect the parent and all other children
            if state.sidebarSelectionState.isSelected(parent) {
                state.sidebarSelectionState.resetSelections()
                state.sidebarSelectionState = addExclusivelyToPrimary(id, state.sidebarSelectionState)
            }

            // ... otherwise, just primarily select the child
            else {
                state.sidebarSelectionState = addExclusivelyToPrimary(
                    id,
                    state.sidebarSelectionState)
            }
        }

        // else: simple case?:
        else {
            state.sidebarSelectionState = addExclusivelyToPrimary(id, state.sidebarSelectionState)
        }
        
        // log("SidebarItemSelected: state.sidebarSelectionState is now: \(state.sidebarSelectionState)")
    }
}

struct SidebarItemDeselected: GraphEvent {
    let id: LayerNodeId

    func handle(state: GraphState) {

        log("SidebarItemDeselected: id: \(id)")
        
        
        // if we deselected a group,
        // then we should also deselect all its children.
        let groups = state.getSidebarGroupsDict()
        
        log("SidebarItemDeselected: groups: \(groups)")
        log("SidebarItemDeselected: state.sidebarSelectionState was: \(state.sidebarSelectionState)")

        var idsToDeselect = LayerIdSet([id])

        groups[id]?.forEach({ (childId: LayerNodeId) in
            // ids all ids to remove
            let ids = getDescendantsIds(
                id: childId,
                groups: groups,
                acc: idsToDeselect)
            idsToDeselect = idsToDeselect.union(ids)

        })

        // log("SidebarItemDeselected: idsToDeselect: \(idsToDeselect)")

        // now that we've gathered all the ids (ie directly de-selected item + its descendants),
        // we can remove them
        idsToDeselect.forEach { idToRemove in
            state.sidebarSelectionState = removeFromSelections(
                idToRemove,
                state.sidebarSelectionState)
        }
    }
}
