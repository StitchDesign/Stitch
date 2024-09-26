//
//  SidebarListItemSelectionActions.swift
//  prototype
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

func secondarilySelectAllChildren(id: LayerNodeId,
                                  groups: SidebarGroupsDict,
                                  acc: SidebarSelectionState) -> SidebarSelectionState {

    var acc = acc

    // add to acc
    acc = addExclusivelyToSecondary(id, acc)

    // recur on children
    if let children = groups[id] {
        children.forEach { (child: LayerNodeId) in
            acc.combine(other: secondarilySelectAllChildren(
                            id: child,
                            groups: groups,
                            acc: acc))
        }
    }

    return acc
}

// children to deselect
func getDescendantsIds(id: LayerNodeId,
                       groups: SidebarGroupsDict,
                       acc: LayerIdSet) -> LayerIdSet {

    var acc = acc
    acc.insert(id)

    // recur on children
    if let children = groups[id] {
        children.forEach { (child: LayerNodeId) in
            acc = acc.union(getDescendantsIds(id: child,
                                              groups: groups,
                                              acc: acc))
        }
    }

    return acc
}

func removeFromSelections(_ id: LayerNodeId,
                          _ selection: SidebarSelectionState) -> SidebarSelectionState {

    var selection = selection

    selection.primary.remove(id)
    selection.secondary.remove(id)

    return selection
}

func addExclusivelyToPrimary(_ id: LayerNodeId,
                             _ selection: SidebarSelectionState) -> SidebarSelectionState {

    var selection = selection

    // add to primary
    selection.primary.insert(id)

    // ... and remove from secondary (migt not be present?):
    selection.secondary.remove(id)

    return selection
}

func addExclusivelyToSecondary(_ id: LayerNodeId,
                               _ selection: SidebarSelectionState) -> SidebarSelectionState {

    var selection = selection

    selection.secondary.insert(id)
    selection.primary.remove(id)

    return selection
}


func allShareSameParent(_ selections: NonEmptySidebarSelections,
                        groups: SidebarGroupsDict) -> Bool {

    if let parent = findGroupLayerParentForLayerNode(selections.first, groups) {
        return selections.allSatisfy { (id: LayerNodeId) in
            // does `id` have a parent, and is that parent the same as the random parent?
            findGroupLayerParentForLayerNode(id, groups).map { $0 == parent } ?? false
        }
    } else {
        return false // ie no parent
    }
}

// selections can only be grouped if they ALL belong to EXACT SAME PARENT (or top level)
// ASSUMES NON-EMPTY
func canBeGrouped(_ selections: NonEmptySidebarSelections,
                  groups: SidebarGroupsDict) -> Bool {

    // items are on same level if they are all top level
    let allTopLevel = selections.allSatisfy {
        !findGroupLayerParentForLayerNode($0, groups).isDefined
    }

    // ... or if they all have same parent
    let allSameParent = allShareSameParent(selections, groups: groups)

    return allTopLevel || allSameParent
}

// Can ungroup selections just if:
// 1. at least one group is 100% selected, and
// 2. no non-group items are 100% selected
func canUngroup(_ primarySelections: SidebarSelections,
                nodes: LayerNodesForSidebarDict) -> Bool {

    !groupPrimarySelections(primarySelections,
                            nodes: nodes).isEmpty

        && nonGroupPrimarySelections(primarySelections,
                                     nodes: nodes).isEmpty
}

// 100% selected items that ARE groups
func groupPrimarySelections(_ primarySelections: SidebarSelections,
                            nodes: LayerNodesForSidebarDict) -> LayerIdList {

    primarySelections.filter { (selected: LayerNodeId) in
        if let node = nodes[selected] {
            return node.layer == .group
        }
        return false
    }
}

// 100% selected items that are NOT groups
func nonGroupPrimarySelections(_ primarySelections: SidebarSelections,
                               nodes: LayerNodesForSidebarDict) -> LayerIdList {

    primarySelections.filter { (selected: LayerNodeId) in
        if let node = nodes[selected] {
            return node.layer != .group
        }
        return false
    }
}

func canDuplicate(_ primarySelections: SidebarSelections) -> Bool {
    !primarySelections.isEmpty
}

// When an individual sidebar item is deleted via the swipe menu
struct SidebarItemDeleted: GraphEvent {
    let itemId: SidebarListItemId

    func handle(state: GraphState) {
        state.deleteNode(id: itemId.asNodeId)
        state.updateSidebarListStateAfterStateChange()
                
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
    }
}
