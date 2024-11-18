//
//  InsertNodeMenuState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/31/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct InsertNodeMenuState: Equatable, Hashable {
    /// Is the menu view animating down to a node view?
    // True = we are currently animating
    // False = we are not animating, or the menu has just first been shown.
    var menuAnimatingToNode: Bool = false

    // The bounds of the user-committed node; we need this node size so that we can know the starting size for animation node.
//    var activeSelectionBounds: CGRect?

    // Whether the menu shows or not; not the same as whether we're animating.
    var show = false

    var searchResults: [InsertNodeMenuOptionData] = allSearchOptions

    // Ensures an option is selected when the menu appears
    // Assumption: can be nil if user filters for a string no node matches, e.g. "QW@#1"
    var activeSelection: InsertNodeMenuOptionData? = Self.startingActiveSelection

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
}
