//
//  SidebarSelectedItemsDuplicated.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation

// TODO: what happens if you duplicate a video layer node?
struct SidebarSelectedItemsDuplicated: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {
        state.visibleGraph.sidebarSelectedItemsDuplicated(document: state)
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    @MainActor
    func sidebarSelectedItemsDuplicated(originalOptionDraggedLayer: SidebarListItemId? = nil,
                                        document: StitchDocumentViewModel) {
        let nodeIds = self.layersSidebarViewModel.selectionState.primary
        self.copyAndPasteSelectedNodes(selectedNodeIds: nodeIds,
                                       originalOptionDraggedLayer: originalOptionDraggedLayer,
                                       document: document)
        
        // Move nodes
    }
}
