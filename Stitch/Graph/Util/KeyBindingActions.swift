//
//  KeyBindingActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import StitchSchemaKit

extension NodeRowViewModelId {
    var asNodeIOCoordinate: NodeIOCoordinate {
        NodeIOCoordinate(portType: self.portType,
                         nodeId: self.nodeId)
    }
}

struct ArrowPressedWhileInputTextFieldFocused: StitchDocumentEvent {
    let wasUpArrow: Bool // currently only up vs down arrows supported
    
    func handle(state: StitchDocumentViewModel) {
        
        guard state.reduxFocusedField?.getTextInputEdit.isDefined ?? false else {
            fatalErrorIfDebug("ArrowKeyPressedWhileInputTextFieldFocused: no text field focused")
            // Should never happen
            return
        }
                
        // View then responds to this
        state.reduxFocusedFieldChangedByArrowKey = wasUpArrow ? .upArrow : .downArrow
    }
}

/// Process arrow key events.
struct ArrowKeyPressed: StitchDocumentEvent {
    let arrowKey: ArrowKey

    func handle(state: StitchDocumentViewModel) {
        log("ArrowKeyPressed: \(arrowKey) called.")

        // Update selected option for insert node menu
        if let activeNodeSelection = Self.willNavigateActiveNodeSelection(state) {
            let insertNodeMenuState = state.insertNodeMenuState

            switch arrowKey {
            case .up:
                state.insertNodeMenuState.activeSelection =
                    Self.nodeMenuSelectionArrowUp(activeSelection: activeNodeSelection,
                                                  queryResults: insertNodeMenuState.searchResults)
            case .down:
                state.insertNodeMenuState.activeSelection =
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

    @MainActor
    private static func willNavigateActiveNodeSelection(_ document: StitchDocumentViewModel) -> InsertNodeMenuOptionData? {
        let insertNodeMenuState = document.insertNodeMenuState

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
        if let document = self.currentDocument {
            document.visibleGraph.resetAlertAndSelectionState(document: document)
        }
        
        // Reset alert state
        self.alertState = ProjectAlertState()
    }
}
