//
//  InsertNodeMenuActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/31/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/// Toggles state to show the menu for inserting a new patch or layer node to the graph.

// i.e. user toggled the insert-node-menu via
struct ToggleInsertNodeMenu: GraphUIEvent {
    func handle(state: GraphUIState) {
        log("ToggleInsertNodeMenu called")
        if !state.insertNodeMenuState.menuAnimatingToNode {
            state.toggleInsertNodeMenu()
            state.doubleTapLocation = nil
        }
    }
}

//// HELPFUL FOR SPECIFIC DEBUG SCENARIOS
//struct ToggleInsertNodeMenu: GraphEvent {
//    func handle(state: GraphState) {
//        log("ToggleInsertNodeMenu CALLED; WILL JUST INSERT AN ADD-NODE")
////        let _ = state.nodeCreated(choice: .patch(.add))
////        createProjectThumbnail(state)
//    }
//}

extension GraphUIState {
    func toggleInsertNodeMenu() {

        // Do not animate the update of the active-selection etc.
        self.insertNodeMenuState.searchResults = InsertNodeMenuState.allSearchOptions

        let isMenuShowing = self.insertNodeMenuState.show
        let showMenu = !isMenuShowing

        //        self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection

        self.activelyEditedCommentBoxTitle = nil

        if showMenu {
            self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection
        } else {
            // Note: active-selection can be nil when search results give nothing; but should we really set it `nil` when we close the menu ?
//            self.insertNodeMenuState.activeSelection = nil
            
            // CHANGED
            // BAD:
            self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection
        }

        // Only animate the properties relevant to animation
        
        // `withAnimation` still seems to cause view to scroll
        
        withAnimation {
            self.insertNodeMenuState.show = showMenu

            // whenever we toggle (open or close) the menu,
            // set `menuAnimating = false`
            self.insertNodeMenuState.menuAnimatingToNode = false
        }
    }
}

/// Resets all state include hiding the menu and the node selection.
struct CloseAndResetInsertNodeMenu: GraphUIEvent {
    func handle(state: GraphUIState) {
        // log("CloseAndResetInsertNodeMenu called")

        if !state.insertNodeMenuState.menuAnimatingToNode {
            withAnimation {
                state.insertNodeMenuState = InsertNodeMenuState()
            }
        }
    }
}

// i.e. User has 'committed' their node-menu selection
struct AddNodeButtonPressed: GraphEventWithResponse {
    func handle(state: GraphState) -> GraphResponse {
        
        // Immediately create a LayerNode; do not animate.
        if let nodeKind = state.graphUI.insertNodeMenuState.activeSelection?.data.kind,
           nodeKind.isLayer {
            let newId = state.nodeCreated(choice: nodeKind)
            if !newId.isDefined {
                fatalErrorIfDebug() // should not fail to return
            }
            state.nodeCreationCompleted(newId)
            return .shouldPersist
        } else {
            // Allows us to render the 'node-sizing-reading' view, which kicks off the animation as soon as its size has been read.
            state.graphUI.insertNodeMenuState.readActiveSelectionSize = true
            return .noChange
        }
    }
}

// fka `AddNodeButtonPressed`
struct ActiveSelectionSizeReadingCompleted: GraphEvent {
    
    let activeSelection: InsertNodeMenuOptionData?
    
    func handle(state: GraphState) {
        
        // log("ActiveSelectionSizeReadingCompleted called: activeSelection: \(activeSelection)")
        
        state.graphUI.insertNodeMenuState.readActiveSelectionSize = false
        
        guard let activeSelection = activeSelection,
              //        guard let activeSelection = state.graphUI.insertNodeMenuState.activeSelection,
              let nodeKind = activeSelection.data.kind else {
            log("ActiveSelectionSizeReadingCompleted: no active selection; exiting")
            return
        }
        
        // Create the real node, but hide it until animation has completed.
        // (Versus the "animated node" which is really just a NodeView created from activeSelection.)
        guard let nodeId = state.nodeCreated(choice: nodeKind) else {
            fatalErrorIfDebug()
            return
        }
        
        // Effectively: insertion-animation has started;
        // We hide the "real node" (the node that lives in GraphState)
        // until the animation has completed.
        state.graphUI.insertNodeMenuState.hiddenNodeId = nodeId
        
        // TODO: use the
        withAnimation {
            // log("ActiveSelectionSizeReadingCompleted: withAnimation")
            state.graphUI.insertNodeMenuState.menuAnimatingToNode = true
            
            // TODO: get rid of this manual dispatch of the completed-animation action
            // TODO: why are the 0.3 extra seconds required?
            // TODO: base the 0.9 off of the existing animation's duration
            //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                dispatch(InsertNodeAnimationCompleted())
            }
        }
        
        // TODO: `completion` animation callback seems either delayed, or in some cases not to fire at all?
        //        completion: {
        //            log("ActiveSelectionSizeReadingCompleted completion")
        //            // Can we do this, dispatch an action from a completion?
        //            // else we could move these changes to an onChange listener in the view ?
        //            dispatch(InsertNodeAnimationCompleted())
        //        }
    }
}

extension GraphState {
    
    @MainActor
    func nodeCreationCompleted(_ immediatelyCreatedLayerNode: NodeId? = nil) {
        
        if let newlyCreatedNodeId = immediatelyCreatedLayerNode ?? self.graphUI.insertNodeMenuState.hiddenNodeId {
            
            self.maybeCreateLLMAddNode(newlyCreatedNodeId)
        } else {
            log("nodeCreationCompleted: finished creating node, but had neither id of immediately created layer node nor id of the node during animation")
            fatalErrorIfDebug()
        }
                
         // log("InsertNodeAnimationCompleted called")

        // hide the menu and animated-node
        self.graphUI.insertNodeMenuState.show = false

        // mark the animation as completed
        self.graphUI.insertNodeMenuState.menuAnimatingToNode = false

        // unhide the real node
        self.graphUI.insertNodeMenuState.hiddenNodeId = nil

        // reset active selection
        //        self.graphUI.insertNodeMenuState.activeSelection = nil
        self.graphUI.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection
        
        self.graphUI.insertNodeMenuState.activeSelectionBounds = nil

        // reset double tap location, now that animation has completed
        self.graphUI.doubleTapLocation = nil
    }
}

struct InsertNodeAnimationCompleted: GraphEventWithResponse {

    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        state.nodeCreationCompleted()
        return .shouldPersist
    }
}
