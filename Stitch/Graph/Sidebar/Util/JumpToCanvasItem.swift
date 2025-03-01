//
//  SidebarItemTapped.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//


import SwiftUI
import StitchSchemaKit

extension GraphState {
    @MainActor
    func jumpToCanvasItem(id: CanvasItemId,
                          graphUI: GraphUIState) {
        self.panGraphToNodeLocation(id: id,
                                    graphUI: graphUI)
    }
    
    @MainActor
    func jumpToAssignedBroadcaster(wirelessReceiverNodeId: NodeId,
                                   graphUI: GraphUIState) {
        if let assignedBroadcaster = self.getNodeViewModel(wirelessReceiverNodeId)?.currentBroadcastChoiceId {
            self.panGraphToNodeLocation(id: .node(assignedBroadcaster),
                                        graphUI: graphUI)
        }
    }
    
    @MainActor
    func findSomeCanvasItemOnGraph(graphUI: GraphUIState) {
        if let canvasItem = GraphState.westernMostNode(
            self.groupNodeFocused,
            canvasItems: self.getCanvasItemsAtTraversalLevel()) {
            
            self.panGraphToNodeLocation(id: canvasItem.id,
                                        graphUI: graphUI)
        }
    }
    
    // TODO: anywhere this isn't being used but should be?
    @MainActor
    func panGraphToNodeLocation(id: CanvasItemId,
                                graphUI: GraphUIState) {
        guard let canvasItem = self.getCanvasItem(id) else {
            fatalErrorIfDebug("panGraphToNodeLocation: no canvasItem found")
            return
        }
        
        guard let jumpPosition = self.getNodeGraphPanLocation(id: id) else {
            log("panGraphToNodeLocation: could not retrieve jump location")
            return
        }
        
        self.graphUI.canvasJumpLocation = jumpPosition
        
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems(graphUI: graphUI)
        canvasItem.select(self)
        
        // Update focused group
        if let newGroup = canvasItem.parentGroupNodeId {
            // TODO: need panning logic for component
            self.graphUI.groupNodeBreadcrumbs.append(.groupNode(newGroup))
        }
    }
    
    // nil could not be be found
    @MainActor
    func getNodeGraphPanLocation(id: CanvasItemId) -> CGPoint? {
                
        guard let cachedBounds = self.visibleNodesViewModel.infiniteCanvasCache.get(id) else {
            // Can be `nil` when called for a canvas item that has never yet been on-screen
            return nil
        }
        
        let scale: CGFloat = self.documentDelegate?.graphMovement.zoomData ?? 1
        
        return CGPoint(
            // TODO: why do we have to SUBTRACT rather than add?
            x: (cachedBounds.origin.x * scale) - self.graphUI.frame.size.width/2,
            y: (cachedBounds.origin.y * scale) - self.graphUI.frame.size.height/2
        )
    }
}
