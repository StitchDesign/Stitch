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

extension GraphState {
    func sidebarSelectedItemsDeletingViaEditMode() {
        let deletedIds = self.sidebarSelectionState.all.map(\.id)
        
        deletedIds.forEach {
            self.visibleNodesViewModel.nodes.removeValue(forKey: $0)
        }

        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
    }
}
