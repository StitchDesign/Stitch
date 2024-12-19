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
            state.groupNodeFocused,
            canvasItems: state.getVisibleCanvasItems()) {
            
            state.panGraphToNodeLocation(id: canvasItem.id)
        }
    }
}

extension GraphState {
    @MainActor
    func panGraphToNodeLocation(id: CanvasItemId) {
        guard let canvasItem = self.getCanvasItem(id) else {
            fatalErrorIfDebug("panGraphToNodeLocation: no canvasItem found")
            return
        }
        
        log("panGraphToNodeLocation: canvasItem \(id)")

        // location of canvasItem
        let position = canvasItem.position
        // ^^ should already exist when new group node created, because the child node already existed
        
        log("panGraphToNodeLocation: position \(position)")

        let newLocation = calculateMove(
            // size of GraphBaseView
            self.graphUI.frame,
            position)
        
        log("panGraphToNodeLocation: newLocation \(newLocation)")
        
        

        // TODO: how to slowly move over to the tapped layer? Using `withAnimation` on just graph offset does not animate the edges. (There's also a canvasItem text issue?)
        //        withAnimation(.easeInOut) {
//        self.graphMovement.localPosition = newLocation
//        self.graphMovement.localPreviousPosition = newLocation
        //        }

//        self.graphUI.canvasJumpLocation = newLocation
        
        
        let nodePosition = CGPoint(x: 1148, y: 645)
//        
//        let jumpPosition = CGPoint(
////            x: 1148 + self.graphUI.frame.size.width/2,
////            y: 645 + self.graphUI.frame.size.height/2
//            
//            
//            // TODO: why do we have to SUBTRACT rather than add?
//            x: 1148 - self.graphUI.frame.size.width/2,
//            y: 645 - self.graphUI.frame.size.height/2
//        )
        // ^^ take view port into account
        
        // also ... scale ?
        
        let scale: CGFloat = self.documentDelegate?.graphMovement.zoomData.final ?? 1
        
        let jumpPosition = CGPoint(
//            x: 1148 + self.graphUI.frame.size.width/2,
//            y: 645 + self.graphUI.frame.size.height/2
            
            
            // TODO: why do we have to SUBTRACT rather than add?
            x: (1148 * scale) - self.graphUI.frame.size.width/2,
            y: (645 * scale) - self.graphUI.frame.size.height/2
        )
        
        log("panGraphToNodeLocation: scale: \(scale)")
        log("panGraphToNodeLocation: jumpPosition: \(jumpPosition)")
        
        
        
        self.graphUI.canvasJumpLocation = jumpPosition
        
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        canvasItem.select()
        
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

    log("calculateMove: childPosition: \(childPosition)")
    log("calculateMove: distance: \(distance)")
    log("calculateMove: newOffset: \(newOffset)")

    return newOffset
}
