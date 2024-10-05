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
        Task(priority: .high) { [weak self] in
            guard let graph = self else { return }
            await graph.copyAndPasteSelectedNodes(selectedNodeIds: graph.sidebarSelectionState.all.map(\.asNodeId).toSet)
        }
    }
}
