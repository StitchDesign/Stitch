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
struct ToggleInsertNodeMenu: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("ToggleInsertNodeMenu called")

        state.toggleInsertNodeMenu()
        state.insertNodeMenuState.doubleTapLocation = nil
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

extension StitchDocumentViewModel {
    @MainActor
    func toggleInsertNodeMenu() {

        // Do not animate the update of the active-selection etc.
        self.insertNodeMenuState.searchResults = InsertNodeMenuState.allSearchOptions

        let isMenuShowing = self.insertNodeMenuState.show
        let showMenu = !isMenuShowing

        //        self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection

//        self.activelyEditedCommentBoxTitle = nil

        if showMenu {
            self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection
        } else {
            // Note: active-selection can be nil when search results give nothing; but should we really set it `nil` when we close the menu ?
//            self.insertNodeMenuState.activeSelection = nil
            
            // CHANGED
            // BAD:
            self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection
        }

        self.insertNodeMenuState.show = showMenu
    }
}

extension Animation {
    static let INSERT_NODE_MENU_TOGGLE_ANIMATION = Self.spring(duration: 0.2)
}

/// Resets all state include hiding the menu and the node selection.
struct CloseAndResetInsertNodeMenu: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("CloseAndResetInsertNodeMenu called")

        state.insertNodeMenuState = InsertNodeMenuState()
    }
}

// i.e. User has 'committed' their node-menu selection
struct AddNodeButtonPressed: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        
        guard let nodeKind = state.insertNodeMenuState.activeSelection?.data.kind else {
            return
        }
        
        let graph = state.visibleGraph
        
        // Reset focused field
        if state.reduxFocusedField != nil {
            state.reduxFocusedField = nil
        }
        
        switch nodeKind {
            
        case .layer(let layer):
            let newNode = state.nodeInserted(choice: .layer(layer))
            state.nodeCreationCompleted(newNode.id)
            graph.persistNewNode(newNode)

        case .patch(let patch):
            let node = state.nodeInserted(choice: .patch(patch))
            let createdNodeId = node.id
            graph.persistNewNode(node)
            // MARK: with animation disabled we now call this immediately
            dispatch(InsertNodeAnimationCompleted(createdNodeId: createdNodeId))
            withAnimation {
                state.insertNodeMenuState.show = false
            }
            
        default: // TODO: handle inserting a component
            break
        }
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func nodeCreationCompleted(_ immediatelyCreatedLayerNode: NodeId?) {
                
         // log("InsertNodeAnimationCompleted called")

        // hide the menu and animated-node
        self.insertNodeMenuState.show = false

        // reset active selection
        //        self.insertNodeMenuState.activeSelection = nil
        self.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection

        // reset double tap location, now that animation has completed
        self.insertNodeMenuState.doubleTapLocation = nil
    }
}

struct InsertNodeAnimationCompleted: StitchDocumentEvent {
    let createdNodeId: NodeId

    @MainActor
    func handle(state: StitchDocumentViewModel) {
        state.nodeCreationCompleted(createdNodeId)
    }
}
