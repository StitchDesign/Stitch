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
        
        let selectedNodeIds = self.layersSidebarViewModel.selectionState.primary
        
        guard let rootUrl = document.documentEncoder?.rootUrl else {
            return
        }
        
        let groupNodeFocused = document.groupNodeFocused
        
        // Copy nodes if no drag started yet
        let copyResult = self.createCopiedComponent(groupNodeFocused: groupNodeFocused,
                                                    selectedNodeIds: selectedNodeIds)
        
        let (destinationGraphEntity, newNodes, nodeIdMap) = Self.insertNodesAndSidebarLayersIntoDestinationGraph(
            destinationGraph: self.createSchema(),
            graphToInsert: copyResult.component.graphEntity,
            focusedGroupNode: groupNodeFocused?.groupNodeId,
            destinationGraphInfo: nil,
            originalOptionDraggedLayer: originalOptionDraggedLayer)
            
        self.update(from: destinationGraphEntity, rootUrl: rootUrl)

        self.updateGraphAfterPaste(newNodes: newNodes,
                                   nodeIdMap: nodeIdMap,
                                   isOptionDragInSidebar: originalOptionDraggedLayer.isDefined)
    }
}
