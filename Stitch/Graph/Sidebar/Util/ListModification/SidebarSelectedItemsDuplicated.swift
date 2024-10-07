//
//  SidebarSelectedItemsDuplicated.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation

// TODO: what happens if you duplicate a video layer node?
struct SidebarSelectedItemsDuplicated: GraphEventWithResponse {

    func handle(state: GraphState) -> GraphResponse {
        state.sidebarSelectedItemsDuplicatedViaEditMode()
        return .persistenceResponse
    }
}

extension GraphState {
    @MainActor
    func sidebarSelectedItemsDuplicatedViaEditMode() {
        self.copyAndPasteSelectedNodes(selectedNodeIds: self.sidebarSelectionState.all.map(\.asNodeId).toSet)
    }
}
