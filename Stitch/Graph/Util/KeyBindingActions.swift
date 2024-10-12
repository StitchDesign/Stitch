//
//  KeyBindingActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import StitchSchemaKit

/// Process arrow key events.
struct ArrowKeyPressed: GraphEvent {
    let arrowKey: ArrowKey

    func handle(state: GraphState) {
        log("ArrowKeyPressed: \(arrowKey) called.")

        // Update selected option for insert node menu
        if let activeNodeSelection = Self.willNavigateActiveNodeSelection(state.graphUI) {
            let insertNodeMenuState = state.graphUI.insertNodeMenuState

            switch arrowKey {
            case .up:
                state.graphUI.insertNodeMenuState.activeSelection =
                    Self.nodeMenuSelectionArrowUp(activeSelection: activeNodeSelection,
                                                  queryResults: insertNodeMenuState.searchResults)
            case .down:
                state.graphUI.insertNodeMenuState.activeSelection =
                    Self.nodeMenuSelectionArrowDown(activeSelection: activeNodeSelection,
                                                    queryResults: insertNodeMenuState.searchResults)
            default:
                return
            }
        }

        // Pan graph if no menu
        // TODO pan graph
        return
    }

    private static func willNavigateActiveNodeSelection(_ graphUI: GraphUIState) -> InsertNodeMenuOptionData? {
        let insertNodeMenuState = graphUI.insertNodeMenuState

        guard insertNodeMenuState.show else {
            return nil
        }
        return insertNodeMenuState.activeSelection
    }

    private static func nodeMenuSelectionArrowUp(activeSelection: InsertNodeMenuOptionData,
                                                 queryResults: [InsertNodeMenuOptionData]) -> InsertNodeMenuOptionData {
        // Find current index of active selection
        guard let currentIndex = queryResults
                .firstIndex(where: { $0.data == activeSelection.data }),
              let nextResult = queryResults[safe: currentIndex - 1] else {
            return activeSelection
        }

        return nextResult
    }

    private static func nodeMenuSelectionArrowDown(activeSelection: InsertNodeMenuOptionData,
                                                   queryResults: [InsertNodeMenuOptionData]) -> InsertNodeMenuOptionData {

        // Find current index of active selection
        guard let currentIndex = queryResults.firstIndex(where: { $0.data == activeSelection.data}),
              let prevResult = queryResults[safe: currentIndex + 1] else {
            return activeSelection
        }

        return prevResult
    }
}

extension StitchStore {
    @MainActor
    func escKeyPressed() {
        // Reset GraphUI state
        if let graphState = self.currentDocument?.visibleGraph {
            graphState.resetAlertAndSelectionState()
        }
        
        // Reset alert state
        self.alertState = ProjectAlertState()
    }
}
