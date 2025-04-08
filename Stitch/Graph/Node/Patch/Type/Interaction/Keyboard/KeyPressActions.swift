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

    @MainActor
    func handle(state: StitchDocumentViewModel) {
        // log("KeyModifierPressEnded: modifiers: \(modifiers)")
        for modifier in modifiers {
            state.keypressState.modifiers.remove(modifier)
        }
    }
}

struct KeyModifierPressBegan: StitchDocumentEvent {
    let name: KeyListenerName
    let modifiers: Set<StitchKeyModifier>

    @MainActor
    func handle(state: StitchDocumentViewModel) {
         // log("KeyModifierPressBegan: listener \(name) had modifiers: \(modifiers)")
        
        let graph = state.visibleGraph
        state.keypressState.modifiers = state.keypressState.modifiers.union(modifiers)
        
        // if TAB pressed and  move forward one foucsed , or SHIFT + TAB,
        let shiftHeld = state.keypressState.isShiftPressed
        let tabPressed = state.keypressState.isTabPressed
        
        let shiftTabPressed = shiftHeld && tabPressed
        
        // // log("KeyModifierPressBegan: shiftHeld: \(shiftHeld)")
         // log("KeyModifierPressBegan: tabPressed: \(tabPressed)")
         // log("KeyModifierPressBegan: shiftTabPressed: \(shiftTabPressed)")
        
        let focusedField = state.reduxFocusedField
        
        // When we tab, we change the edge editing state's nearbyNode, labelsShown, and possible and shown edges
        // but hovered output and nodest-to-the-east stays the same
        if let edgeEditingState = graph.edgeEditingState,
           name == .mainGraph,
           tabPressed {
            
            graph.edgeEditingState = edgeEditingState.canvasItemIndexChanged(
                edgeEditState: edgeEditingState,
                graph: graph,
                wasIncremented: shiftTabPressed ? false : true,
                groupNodeFocused: state.groupNodeFocused?.groupNodeId)
            
            return
        }
        
        // Tabbing between inputs project setting's preview window dimensions fields
        if focusedField == .previewWindowSettingsWidth, tabPressed {
            // Both tab and shift-tab move us to height
            state.reduxFocusedField = .previewWindowSettingsHeight
            return
        } else if focusedField == .previewWindowSettingsHeight, tabPressed {
            // Both tab and shift-tab move us to height
            state.reduxFocusedField = .previewWindowSettingsWidth
            return
        }
        // Ignore shift/tab if no node input field is focused.
        else if let focusedField = focusedField?.getTextInputEdit,
                let node = graph.getNode(focusedField.rowId.nodeId) {
            if shiftTabPressed {
                state.shiftTabPressed(focusedField: focusedField,
                                      node: node)
            } else if tabPressed {
                state.tabPressed(focusedField: focusedField,
                                 node: node)
            }
        }
    }
}

// TODO: more like?: `RemoveCommandKeyModifier`
struct KeyModifierReset: StitchDocumentEvent {
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        // BAD: resets all key press state, including isSpacePressed etc.
        //        state.keypressState = .init()

        // BETTER: just remove the specfic modifier that was causing problems: CMD
        state.keypressState.modifiers.remove(.cmd)
    }
}

extension NodesViewModelDict {
    @MainActor
    var keyboardNodes: NodeViewModels {
        self.nodes(for: .keyboard)
    }

    @MainActor
    var locationNodes: NodeViewModels {
        self.nodes(for: .location)
    }

    @MainActor
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
    
        if document.reduxFocusedField.isDefined {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since some field is focused")
            return
        }
        
        // if insert node menu is open, ignore key presses:
        if document.insertNodeMenuState.show {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since insert node menu is open")
            return
        }

        if self.alertState.showProjectSettings {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since project settings modal is open")
            return
        }
        
        let graph = document.visibleGraph

        // We always add `char` to key press state,
        // but if we're currently hovering over an output (= edge-editing mode),
        // we won't recalculate the graph (= won't update keyboard patch nodes).

        // TODO: edge-added and edge-removed logic still recalculate the graph
        document.keypressState.characters.insert(char)

        if graph.edgeEditingState.isDefined {
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

    @MainActor
    func handle(state: StitchDocumentViewModel) {
        
        // log("KEY: KeyCharacterPressEnded: char: \(char)")
        
        if state.reduxFocusedField.isDefined {
            // log("KEY: KeyCharacterPressBegan: ignoring key press for char \(char) since some field is focused")
            return
        }
        
        // log("KEY: KeyCharacterPressEnded: graphState.keypressState.isSpacePressed was: \(graphState.keypressState.isSpacePressed)")

        // NOTE: Always let key presses end, even if insert-node-menu or project settings modal is open

        // remove the key to the pressed-characters
        state.keypressState.characters.remove(char)

        // log("KEY: KeyCharacterPressEnded: graphState.keypressState.isSpacePressed is now: \(graphState.keypressState.isSpacePressed)")

        // recalculate all the keyboard nodes on the graph
        state.calculateAllKeyboardNodes()
    }
}
