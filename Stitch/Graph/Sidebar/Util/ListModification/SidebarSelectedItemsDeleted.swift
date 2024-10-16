//
//  SidebarSelectedItemsDeleted.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// MARK: actions on currently selected items

struct SidebarSelectedItemsDeleted: GraphEventWithResponse {

    func handle(state: GraphState) -> GraphResponse {
        state.sidebarSelectedItemsDeletingViaEditMode()
        return .shouldPersist
    }
}

extension ProjectSidebarObservable {
    func sidebarSelectedItemsDeletingViaEditMode() {
        let deletedIds = self.selectionState.all.map(\.id)
        
        self.didItemsDelete(ids: ids)
    }
}

extension LayerSidebarObservable {
    func didItemsDelete(ids: Set<SidebarListItemId>) {
        self.graphDelegate?.didItemsDelete(ids: ids)
    }
}

extension GraphState {
    func didItemsDelete(ids: Set<SidebarListItemId>) {
        let deletedIds = ids.map { $0.asNodeId }
        
        deletedIds.forEach {
            self.visibleNodesViewModel.nodes.removeValue(forKey: $0)
        }

        // TODO: de-selection on edit mode
//        self.updateSidebarListStateAfterStateChange()
//        
//        // TODO: why is this necessary?
//        _updateStateAfterListChange(
//            updatedList: self.sidebarListState,
//            expanded: self.getSidebarExpandedItems(),
//            graphState: self)
    }
}
