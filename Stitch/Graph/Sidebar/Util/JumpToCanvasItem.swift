//
//  SidebarItemTapped.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//


import SwiftUI
import StitchSchemaKit

// MARK: ACTIONS

struct JumpToCanvasItem: GraphEvent {

    let id: CanvasItemId

    func handle(state: GraphState) {
        state.panGraphToNodeLocation(id: id)
    }
}

struct JumpToAssignedBroadcaster: GraphEvent {
    
    let wirelessReceiverNodeId: NodeId
    
    func handle(state: GraphState) {
        if let assignedBroadcaster = state.getNodeViewModel(wirelessReceiverNodeId)?.currentBroadcastChoiceId {
            state.panGraphToNodeLocation(id: .node(assignedBroadcaster))
        }
    }
}

struct FindSomeCanvasItemOnGraph: GraphEvent {
    
    func handle(state: GraphState) {
        if let canvasItem = GraphState.westernMostNode(
            state.groupNodeFocused,
            canvasItems: state.getVisibleCanvasItems()) {
            
            state.panGraphToNodeLocation(id: canvasItem.id)
        }
    }
}

extension GraphState {
    // TODO: anywhere this isn't being used but should be?
    @MainActor
    func panGraphToNodeLocation(id: CanvasItemId) {
        guard let canvasItem = self.getCanvasItem(id) else {
            fatalErrorIfDebug("panGraphToNodeLocation: no canvasItem found")
            return
        }
        
        guard let cachedBounds = self.visibleNodesViewModel.infiniteCanvasCache.get(id) else {
            fatalErrorIfDebug("Could not find cached bounds for canvas item \(id)")
            return
        }
        
        let scale: CGFloat = self.documentDelegate?.graphMovement.zoomData.final ?? 1
        
        let jumpPosition = CGPoint(
            // TODO: why do we have to SUBTRACT rather than add?
            x: (cachedBounds.origin.x * scale) - self.graphUI.frame.size.width/2,
            y: (cachedBounds.origin.y * scale) - self.graphUI.frame.size.height/2
        )
                
        self.graphUI.canvasJumpLocation = jumpPosition
        
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        canvasItem.select(self)
        
        // Update focused group
        if let newGroup = canvasItem.parentGroupNodeId {
            // TODO: need panning logic for component
            self.graphUI.groupNodeBreadcrumbs.append(.groupNode(newGroup))
        }
    }
}

// graphViewFrame is same for screen and nodeView.size;
// we're actually calculate how the nodeView will be moved
// to bring the child into center of screen.
func calculateMove(_ graphViewFrame: CGRect,
                   // the location of child
                   _ childPosition: CGPoint) -> CGPoint {

    // you always know the absolute center
    let center = CGPoint(x: graphViewFrame.midX,
                         y: graphViewFrame.midY)

    let distance = CGPoint(x: center.x - childPosition.x,
                           y: center.y - childPosition.y)

    let newOffset = CGPoint(x: distance.x,
                            y: distance.y)

    // log("calculateMove: childPosition: \(childPosition)")
    // log("calculateMove: distance: \(distance)")
    // log("calculateMove: newOffset: \(newOffset)")

    return newOffset
}
