//
//  KeypressActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/14/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct KeyModifierPressEnded: StitchDocumentEvent {
    let modifiers: Set<StitchKeyModifier>

    func handle(state: StitchDocumentViewModel) {
        // log("KeyModifierPressEnded: modifiers: \(modifiers)")
        for modifier in modifiers {
            state.keypressState.modifiers.remove(modifier)
        }
    }
}

struct KeyModifierPressBegan: StitchDocumentEvent {
    let modifiers: Set<StitchKeyModifier>

    func handle(state: StitchDocumentViewModel) {
         // log("KeyModifierPressBegan: modifiers: \(modifiers)")
        
        state.keypressState.modifiers = state.keypressState.modifiers.union(modifiers)
        
        // if TAB pressed and  move forward one foucsed , or SHIFT + TAB,
        let shiftHeld = state.keypressState.isShiftPressed
        let tabPressed = state.keypressState.isTabPressed
        
        // log("KeyModifierPressBegan: shiftHeld: \(shiftHeld)")
        // log("KeyModifierPressBegan: tabPressed: \(tabPressed)")
        
        // Ignore shift/tab if no node input field is focused.
        if let focusedField = state.graphUI.reduxFocusedField?.getTextInputEdit,
           let node = state.visibleGraph.getNode(focusedField.rowId.nodeId) {
            if shiftHeld, tabPressed {
                state.visibleGraph.shiftTabPressed(focusedField: focusedField,
                                                   node: node)
            } else if tabPressed {
                state.visibleGraph.tabPressed(focusedField: focusedField,
                                              node: node)
            }
        }
    }
}

// TODO: more like?: `RemoveCommandKeyModifier`
struct KeyModifierReset: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // BAD: resets all key press state, including isSpacePressed etc.
        //        state.keypressState = .init()

        // BETTER: just remove the specfic modifier that was causing problems: CMD
        state.keypressState.modifiers.remove(.cmd)
    }
}

extension NodesViewModelDict {
    var keyboardNodes: NodeViewModels {
        self.nodes(for: .keyboard)
    }

    var locationNodes: NodeViewModels {
        self.nodes(for: .location)
    }

    func nodes(for patch: Patch) -> NodeViewModels {
        Array(self.values)
            .compactFilter { $0.kind.getPatch == patch }
    }
}

// This is an AppEnvironmentEvent because we must look at AppState.alertState,
// which tells us if we currently have the specific project's settings modal is open
// (in which case we ignore key presses).
// TODO: project-settings-modal info should be contained on ProjectState, not AppState.
extension StitchStore {
    @MainActor
    func keyCharacterPressBegan(char: Character) {
                        
        // log("KEY: KeyCharacterPressBegan: char: \(char)")
                
        guard let document = self.currentDocument else {
            // log("KEY: KeyCharacterPressBegan: no graphState")
            return
        }
    
        if document.graphUI.reduxFocusedField.isDefined {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since some field is focused")
            return
        }
        
        // if insert node menu is open, ignore key presses:
        if document.graphUI.insertNodeMenuState.show {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since insert node menu is open")
            return
        }

        if self.alertState.showProjectSettings {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since project settings modal is open")
            return
        }

        // We always add `char` to key press state,
        // but if we're currently hovering over an output (= edge-editing mode),
        // we won't recalculate the graph (= won't update keyboard patch nodes).

        // TODO: edge-added and edge-removed logic still recalculate the graph
        document.keypressState.characters.insert(char)

        if document.graphUI.edgeEditingState.isDefined {
            document.keyCharPressedDuringEdgeEditingMode(char: char)
        }

        // Not in edge-edit-mode, so recalc the keyboard patch nodes
        else {
            document.calculateAllKeyboardNodes()
        }
    }
}

struct KeyCharacterPressEnded: StitchDocumentEvent {
    let char: Character

    func handle(state: StitchDocumentViewModel) {
        
        // log("KEY: KeyCharacterPressEnded: char: \(char)")
        
        if state.graphUI.reduxFocusedField.isDefined {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since some field is focused")
            return
        }
        
        // log("KEY: KeyCharacterPressEnded: graphState.graphUI.keypressState.isSpacePressed was: \(graphState.graphUI.keypressState.isSpacePressed)")

        // NOTE: Always let key presses end, even if insert-node-menu or project settings modal is open

        // remove the key to the pressed-characters
        state.keypressState.characters.remove(char)

        // log("KEY: KeyCharacterPressEnded: graphState.graphUI.keypressState.isSpacePressed is now: \(graphState.graphUI.keypressState.isSpacePressed)")

        // recalculate all the keyboard nodes on the graph
        state.calculateAllKeyboardNodes()
    }
}
