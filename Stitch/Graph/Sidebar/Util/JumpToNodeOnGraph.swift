//
//  SidebarItemTapped.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//


import SwiftUI
import StitchSchemaKit

// MARK: ACTIONS

struct JumpToNodeOnGraph: GraphEvent {

    let id: NodeId

    func handle(state: GraphState) {
        state.panGraphToNodeLocation(nodeId: id)
    }
}

struct FindNodeOnGraph: GraphEvent {
    
    func handle(state: GraphState) {
        if let node = GraphState.westernMostNode(
            state.groupNodeFocused?.asGroupNodeId,
            nodeViewModels: state.getVisibleNodes()) {
            
            state.panGraphToNodeLocation(nodeId: node.id)
        }
    }
}

extension GraphState {
    @MainActor
    func panGraphToNodeLocation(nodeId: NodeId) {
        guard let node = self.getNodeViewModel(nodeId) else {
            fatalErrorIfDebug("GraphState.sidebarItemTapped: no node found")
            return
        }

        // the size of the screen and nodeView
        let frame = self.graphUI.frame

        // location of node
        let position = node.position

        let newLocation = calculateMove(frame, position)

        // TODO: how to slowly move over to the tapped layer? Using `withAnimation` on just graph offset does not animate the edges. (There's also a node text issue?)
        //        withAnimation(.easeaInOut) {
        self.graphMovement.localPosition = newLocation
        self.graphMovement.localPreviousPosition = newLocation
        //        }

        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        node.select()
        
        // Update focused group
        self.graphUI.groupNodeFocused = node.parentGroupNodeId?.asGroupNodeId
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
