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
        // Does deletion order matter?
        let deletedIds = state.sidebarSelectionState.all.map(\.id)
        
        deletedIds.forEach {
            state.visibleNodesViewModel.nodes.removeValue(forKey: $0)
        }
        

        state.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)

        return .shouldPersist
    }
}
