//
//  ReduxHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/7/24.
//

import Foundation
import StitchSchemaKit

/*
 Handling an action = producing a response and potentially updating StitchStore/GraphState in-place

 Handling a response = potentially:
 1. running side-effects
 2. updating current StitchStore/GraphState via legacy StateUpdate
 3. updating undo/redo history
 4. writing to disk (persistence)

 Note:
 - we must update StitchStore/GraphState (via legacy StateUpdate) BEFORE we write to disk, else we write outdated data.
 - updating undo/redo history needs both the previous and the new StitchDocument/GraphState
 */

// Note: StitchStore/GraphState may have already been mutated in-place by the handling of the action.
@MainActor
func _handleAction(store: StitchStore, action: Action) {

    // Note: `prevState: AppState?` is the original, pre-action-handling AppState created for a legacy action that required AppState and/or GraphSchema.
    // It is currently required for some write-undo-history use cases.
    let response: AppResponse = _getResponse(from: action,
                                             store: store)

    // 1. Run side-effects
    response.sideEffectCoordinator?.runEffects(dispatch: dispatch)

    // 2. Handle legacy update, if we had one.
    // Updates StitchStore/GraphState in-place.
    if let legacyStateUpdate = response.state {
        handleLegacyStateUpdate(store: store,
                                legacyState: legacyStateUpdate)
    }

    // 3. Write undo history
    Task { [weak store] in
        guard let store = store else {
            return
        }
        
        await store.currentDocument?.documentEncoder
            .writeUndoHistory(store: store,
                              response: response)
    }

    // 4. Write current StitchStore/GraphState to disk.
    if response.shouldPersist {
        // self.currentGraph?.updateGraphData() // from runStitchDispatchMiddleware
        store.encodeCurrentProject()
    }
}

extension DocumentEncoder {
    func writeUndoHistory(store: StitchStore,
                          response: AppResponse) async {

        guard let documentState = store.currentDocument else {
            // log("writeUndoHistory: did not have documentState")
            return
        }

        // TODO: can we ever write undo-history if we had undo-events but shouldPersist=false ?
        if StitchUndoManager.shouldUpdateUndo(
            willPersist: response.shouldPersist,
            containsUndoEvents: !(response.undoEvents ?? []).isEmpty) {

            // log("handleResponse: will update undo history")
            await MainActor.run { [weak store, weak documentState, weak self] in
                guard let documentState = documentState,
                      let encoder = self else {
                    return
                }
                
                let lastEncodedData = encoder.lastEncodedDocument
                let nextData = documentState.createSchema()
                
                // Create copy of next state to be saved in the UndoManager stack
                // If no reframe response but undo, we use StitchDocument
                store?.environment.undoManager.prepareAndSaveUndoHistory(
                    prevDocument: lastEncodedData,
                    nextDocument: nextData,
                    undoEvents: response.undoEvents,
                    redoEvents: response.redoEvents)
            }
        }
    }
}
