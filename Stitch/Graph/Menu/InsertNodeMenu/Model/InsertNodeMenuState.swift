//
//  InsertNodeMenuState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/31/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

    /*
     The id of the "real node" which is added to GraphState when we commit, but hidden until animation completes.
     
     Non-nil also effectively means "We read the size of the active selection, created the real node in GraphState, and have kicked off the animation."
     */
struct UpdateSearchQuery: Action {
    let query: String
}

    /// Is the menu view animating down to a node view?
    // True = we are currently animating
    // False = we are not animating, or the menu has just first been shown.
struct InsertNodeMenuState: Hashable {
    var hiddenNodeId: NodeId?
    var menuAnimatingToNode: Bool = false
    // The bounds of the user-committed node; we need this node size so that we can know the starting size for animation node.
//    var activeSelectionBounds: CGRect?

    // Whether the menu shows or not; not the same as whether we're animating.
    var show = false
    // Moved here from GraphUIState, since only used by 
    var doubleTapLocation: CGPoint?
    var searchResults: [InsertNodeMenuOptionData] = allSearchOptions
    // Ensures an option is selected when the menu appears
    // Assumption: can be nil if user filters for a string no node matches, e.g. "QW@#1"
    var activeSelection: InsertNodeMenuOptionData? = Self.startingActiveSelection
    var searchQuery: String?
    var isGeneratingAINode: Bool = false
    
    static let startingActiveSelection = allSearchOptions.first
    // TODO: needs to be dynamic, since we now must load in custom components
    
    static var allSearchOptions: [InsertNodeMenuOptionData] {
        // Must appear in the same order as we display them in InsertNodeMenu,
        // else key up and down break.
        Layer.searchableLayers
            .map { InsertNodeMenuOptionData(data: .layer($0)) } +
            Patch.searchablePatches
            .map { InsertNodeMenuOptionData(data: .patch($0)) }
        //            Layer.searchableLayers
        //            .map { InsertNodeMenuOptionData(data: .layer($0)) }
        //            + DefaultComponents.allCases
        //            .map { InsertNodeMenuOptionData(data: .defaultComponent($0)) }
    }
    
    var hasResults: Bool {
        searchResults.isEmpty == false
    }
    
    var isAIMode: Bool {
        #if STITCH_AI
        // We're in AI mode if we have a non-empty query and no matching results
        if let query = searchQuery, !query.isEmpty {
            return searchResults.isEmpty
        }
        #endif
        return false
    }
}

// Note: The UpdateSearchQuery action can be removed since we're using InsertNodeQuery
extension InsertNodeMenuState {
    static func reduce(state: inout Self, action: Action) {
        switch action {
        default:
            break
        }
    }
}
