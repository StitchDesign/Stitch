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

struct FindSomeCanvasItemOnGraph: GraphEvent {
    
    func handle(state: GraphState) {
        if let canvasItem = GraphState.westernMostNode(
            state.groupNodeFocused?.asGroupNodeId,
            canvasItems: state.getVisibleCanvasItems()) {
            
            state.panGraphToNodeLocation(id: canvasItem.id)
        }
    }
}

extension GraphState {
    @MainActor
    func panGraphToNodeLocation(id: CanvasItemId) {
        guard let canvasItem = self.getCanvasItem(id) else {
            fatalErrorIfDebug("GraphState.sidebarItemTapped: no canvasItem found")
            return
        }

        // the size of the screen and canvas item's View
        let frame = self.graphUI.frame

        // location of canvasItem
        let position = canvasItem.position

        let newLocation = calculateMove(frame, position)

        // TODO: how to slowly move over to the tapped layer? Using `withAnimation` on just graph offset does not animate the edges. (There's also a canvasItem text issue?)
        //        withAnimation(.easeInOut) {
        self.graphMovement.localPosition = newLocation
        self.graphMovement.localPreviousPosition = newLocation
        //        }

        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        canvasItem.select()
        
        // Update focused group
        self.graphUI.groupNodeFocused = canvasItem.parentGroupNodeId?.asGroupNodeId
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

    //    log("calculateMove: childPosition: \(childPosition)")
    //    log("calculateMove: distance: \(distance)")
    //    log("calculateMove: newOffset: \(newOffset)")

    return newOffset
}
