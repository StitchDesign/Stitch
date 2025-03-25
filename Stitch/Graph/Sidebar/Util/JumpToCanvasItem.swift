//
//  SidebarItemTapped.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//


import SwiftUI
import StitchSchemaKit

struct JumpToCanvasItem: StitchDocumentEvent {
    let id: CanvasItemId
    
    func handle(state: StitchDocumentViewModel) {
        state.visibleGraph.jumpToCanvasItem(id: id, document: state)
    }
}

extension GraphState {
    @MainActor
    func jumpToCanvasItem(id: CanvasItemId,
                          document: StitchDocumentViewModel) {
        self.panGraphToNodeLocation(id: id,
                                    document: document)
    }
    
    @MainActor
    func jumpToAssignedBroadcaster(wirelessReceiverNodeId: NodeId,
                                   document: StitchDocumentViewModel) {
        if let assignedBroadcaster = self.getNodeViewModel(wirelessReceiverNodeId)?.currentBroadcastChoiceId {
            self.panGraphToNodeLocation(id: .node(assignedBroadcaster),
                                        document: document)
        }
    }
    
    @MainActor
    func findSomeCanvasItemOnGraph(document: StitchDocumentViewModel) {
        if let canvasItem = GraphState.westernMostNode(
            document.groupNodeFocused?.groupNodeId,
            canvasItems: self.getCanvasItemsAtTraversalLevel(groupNodeFocused: document.groupNodeFocused?.groupNodeId)) {
            
            self.panGraphToNodeLocation(id: canvasItem.id,
                                        document: document)
        }
    }
    
    // TODO: anywhere this isn't being used but should be?
    @MainActor
    func panGraphToNodeLocation(id: CanvasItemId,
                                document: StitchDocumentViewModel) {
        guard let canvasItem = self.getCanvasItem(id) else {
            fatalErrorIfDebug("panGraphToNodeLocation: no canvasItem found")
            return
        }
        
        guard let jumpPosition = self.getNodeGraphPanLocation(id: id,
                                                              document: document) else {
            log("panGraphToNodeLocation: could not retrieve jump location")
            return
        }
        
        self.canvasJumpLocation = jumpPosition
        
        self.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        canvasItem.select(self)
        
        // Update focused group ONLY IF CHANGED (important to avoid didSet)
        if let canvasItemTraversalLevel = canvasItem.parentGroupNodeId,
           document.groupNodeFocused?.groupNodeId != canvasItemTraversalLevel {
            // TODO: need panning logic for component
            document.groupNodeBreadcrumbs.append(.groupNode(canvasItemTraversalLevel))
        }
    }
    
    // nil could not be be found
    @MainActor
    func getNodeGraphPanLocation(id: CanvasItemId,
                                 document: StitchDocumentViewModel) -> CGPoint? {
                
        guard let cachedBounds = self.visibleNodesViewModel.infiniteCanvasCache.get(id) else {
            // Can be `nil` when called for a canvas item that has never yet been on-screen
            return nil
        }
        
        let scale: CGFloat = document.graphMovement.zoomData
        
        return CGPoint(
            // TODO: why do we have to SUBTRACT rather than add?
            x: (cachedBounds.origin.x * scale) - document.frame.size.width/2,
            y: (cachedBounds.origin.y * scale) - document.frame.size.height/2
        )
    }
}
