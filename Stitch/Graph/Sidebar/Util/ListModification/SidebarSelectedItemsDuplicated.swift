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
        // Update selections UI, which copy/paste logic will use
        
        // Sidebar Selection State
        state.sidebarSelectionState.all.map(\.asNodeId).forEach {
            if let node = state.getNodeViewModel($0) {
                node.select()
            }
        }
        
        state.copyAndPasteSelectedNodes()
        return .persistenceResponse
    }
}

