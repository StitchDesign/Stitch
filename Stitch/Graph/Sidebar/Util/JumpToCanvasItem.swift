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
        state.panGraphToNodeLocation(id: id)
    }
}

struct JumpToWirelessBroadcaster: StitchDocumentEvent {
    let wirelessReceiverNodeId: NodeId
    
    func handle(state: StitchDocumentViewModel) {
        if let assignedBroadcaster = state.visibleGraph.getNodeViewModel(wirelessReceiverNodeId)?.currentBroadcastChoiceId {
            state.panGraphToNodeLocation(id: .node(assignedBroadcaster))
        }
    }
}

struct FindSomeCanvasItemOnGraph: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        if let canvasItem = GraphState.westernMostNode(
            state.groupNodeFocused?.groupNodeId,
            canvasItems: state.visibleGraph.getCanvasItemsAtTraversalLevel(groupNodeFocused: state.groupNodeFocused?.groupNodeId)) {
            
            state.panGraphToNodeLocation(id: canvasItem.id)
        }
    }
}

extension StitchDocumentViewModel {
    // TODO: anywhere this isn't being used but should be?
    @MainActor
    func panGraphToNodeLocation(id: CanvasItemId) {
        
        let graph = self.visibleGraph
        
        // log("panGraphToNodeLocation: called for id: \(id)")
        
        guard let canvasItem = graph.getCanvasItem(id) else {
            fatalErrorIfDebug("panGraphToNodeLocation: no canvasItem found")
            return
        }
        
        let currentTraversalLevel = self.groupNodeFocused?.groupNodeId
        let canvasItemTraversalLevel = canvasItem.parentGroupNodeId
        // log("panGraphToNodeLocation: currentTraversalLevel: \(currentTraversalLevel)")
        // log("panGraphToNodeLocation: canvasItemTraversalLevel: \(canvasItemTraversalLevel)")
        
        // If the canvas item is not at this traversal level (e.g. a layer input that is on the canvas but inside another group),
        // then we have to find which traversal level to jump to, along with the proper breadcrumb path.
        guard canvasItemTraversalLevel == currentTraversalLevel else {
            let result = graph.getBreadcrumbs(
                startingPoint: currentTraversalLevel.map(GroupNodeType.groupNode),
                destination: canvasItem.id)
            
            // log("panGraphToNodeLocation: result: \(result)")
  
            // if tapped canvas item has a shorter breadcrumb path than the current item, just replace the current breadcrumb path
            if result.count <= self.groupNodeBreadcrumbs.count {
                // log("panGraphToNodeLocation: replacing current breadcrumbs")
                self.groupNodeBreadcrumbs = result
            } else {
                // log("panGraphToNodeLocation: appending to current breadcrumbs")
                // Update the breadcrumbs
                self.groupNodeBreadcrumbs.append(contentsOf: result)
                
                // Updates graph data
                self.refreshGraphUpdaterId()
            }
            
            // Allow us to enter the traversal level,
            // and NodeViews to render and populate the infiniteCanvasCache,
            // then attempt to pan again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // log("panGraphToNodeLocation: async")
                self.panGraphToNodeLocation(id: id)
            }
            
            return
        }
        
        guard let jumpPosition = graph.visibleNodesViewModel.getNodeGraphPanLocation(
            id: id,
            documentZoomData: self.graphMovement.zoomData,
            documentFrame: self.frame) else {
            // log("panGraphToNodeLocation: could not retrieve jump location")
            return
        }
        
        graph.canvasJumpLocation = jumpPosition
        
        graph.selection = GraphUISelectionState()
        graph.resetSelectedCanvasItems()
        graph.selectCanvasItem(id)
        
        // Update focused group ONLY IF CHANGED (important to avoid didSet)
        if let canvasItemTraversalLevel = canvasItemTraversalLevel,
           currentTraversalLevel != canvasItemTraversalLevel {
            // TODO: need panning logic for component
            self
                .groupNodeBreadcrumbs
                .append(.groupNode(canvasItemTraversalLevel))
        }
    }
}

extension VisibleNodesViewModel {
    // nil could not be be found
    @MainActor
    func getNodeGraphPanLocation(id: CanvasItemId,
                                 documentZoomData: CGFloat,
                                 documentFrame: CGRect) -> CGPoint? {
                
        guard let cachedBounds = self.infiniteCanvasCache.get(id) else {
            // Can be `nil` when called for a canvas item that has never yet been on-screen
            return nil
        }
        
        let scale: CGFloat = documentZoomData
        
        return CGPoint(
            // TODO: why do we have to SUBTRACT rather than add?
            x: (cachedBounds.origin.x * scale) - documentFrame.size.width/2,
            y: (cachedBounds.origin.y * scale) - documentFrame.size.height/2
        )
    }
}
