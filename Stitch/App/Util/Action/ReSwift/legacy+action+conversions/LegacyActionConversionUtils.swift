//
//  LegacyActionConversionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/8/24.
//

import Foundation
import StitchSchemaKit

// MARK: producing an AppResponse from a legacy `Action`

@MainActor
func _getResponse(from legacyAction: Action,
                  store: StitchStore) -> AppResponse {

    let getState: () -> AppState = store.getState
    let document = store.currentDocument
    let graphState: GraphState? = document?.visibleGraph
    let environment: StitchEnvironment = store.environment
    
    let fileManager = environment.fileManager
    let logListener = environment.logListener
    let undoManager = environment.undoManager

    if let stitchStoreAction = (legacyAction as? StitchStoreEvent) {
        let response = stitchStoreAction.handle(store: store)
        // StitchStore is just an in-place update; but may return side-effects, undo-events etc.
        return response.toAppResponse()
    }
    
    // AppEvents
    else if let appAction = (legacyAction as? AppEvent) {
        let state = getState()
        return appAction.handle(state: state)
    }

    // AppLibraryEvents
    else if let appLibraryAction = (legacyAction as? AppEnvironmentEvent) {
        let state = getState()
        let response = appLibraryAction.handle(state: state,
                                               environment: environment)
        return response
    }

    // ProjectLibraryEvent
    else if let projectLibraryAction = (legacyAction as? ProjectEnvironmentEvent),
            let graphState = graphState {

        let response = projectLibraryAction
            .handle(graphState: graphState,
                    environment: environment)
            .toAppResponse()

        return response
    }
    
    // StitchDocumentEvents
    else if let documentAction = (legacyAction as? StitchDocumentEvent),
            let document = document {
        // Mutates GraphState in-place
        documentAction.handle(state: document)
        return .noChange
    }

    // GraphEvents
    else if let graphAction = (legacyAction as? GraphEvent),
            let graphState = graphState {
        // Mutates GraphState in-place
        graphAction.handle(state: graphState)
        return .noChange
    }
    
    // GraphEvent with response
    else if let graphAction = (legacyAction as? GraphEventWithResponse),
            let graphState = graphState {
        // Mutates GraphState in-place
        let response = graphAction
            .handle(state: graphState)
            .toAppResponse()
        
        return response
    }

    // GraphUIEvents
    else if let graphUIAction = (legacyAction as? GraphUIEvent),
            let graphState = graphState {
        // Mutates GraphState.graphUI in-place
        graphUIAction.handle(state: graphState.graphUI)
        return .noChange
    }

    // Project Alert Events
    else if let projectAlertAction = (legacyAction as? ProjectAlertEvent) {
        let state = getState()
        let response = projectAlertAction
            .handle(state: state.alertState)
            .toAppResponse(state)

        return response
    }

    // TODO: is such a specific signature worth it for only a couple actions?
    else if let fileManagerAction = (legacyAction as? FileManagerEvent) {
        let response = fileManagerAction
            .handle(fileManager: fileManager)
            .toAppResponse()

        return response
    }

    // TODO: is such a specific signature worth it for only a couple actions?
    else if let logAction = (legacyAction as? LogEvent) {
        let response = logAction
            .handle(logListener: logListener, fileManager: fileManager)
            .toAppResponse()

        return response
    }

    // TODO: is such a specific signature worth it for only a couple actions?
    // Undo/redo events
    else if let undoAction = (legacyAction as? UndoManagerEvent) {
        undoAction.handle(undoManager: undoManager)
        return .noChange
    }

    return .noChange
}

// MARK: handling a StateUpdate<T> created by a legacy `Action`

// Previously lived in `StitchStore.reframeReducer`

/*
 We handled a legacy action which returned an updated AppState and/or GraphSchema.
 We must turn this update into an updated StitchStore and/or GraphState.

 Note: The AppState could contain updates for just an AppState property, or just GraphSchema properties, or both.

 Legacy state updates are not used for perf-sensitive cases, so it's okay to "over-update" here.
 */
@MainActor
func handleLegacyStateUpdate(store: StitchStore,
                             // new state
                             legacyState: AppState) {

    // Updating AppState properties on StitchStore
    store.edgeStyle.setOnChange(legacyState.edgeStyle)
    store.appTheme.setOnChange(legacyState.appTheme)
    store.isShowingDrawer.setOnChange(legacyState.isShowingDrawer)
    store.projectIdForTitleEdit.setOnChange(legacyState.projectIdForTitleEdit)
    store.alertState.setOnChange(legacyState.alertState)
}



// MARK: `toAppResponse` helpers for legacy Action

extension ProjectAlertResponse {

    func toAppResponse(_ appState: AppState) -> AppResponse {

        var updatedAppState: AppState?

        if let stateUpdate = self.state {
            updatedAppState = appState
            updatedAppState?.alertState = stateUpdate
        }

        return AppResponse(
            sideEffectCoordinator: self.sideEffectCoordinator,
            state: updatedAppState,
            shouldPersist: self.shouldPersist)
    }
}

// TODO: just use `GraphResponse` instead of `MiddlewareManagerResponse` ?
extension MiddlewareManagerResponse {
    func toAppResponse() -> AppResponse {
        // GraphResponse is just an in-place GraphState update;
        // never produces an updated AppState.
        AppResponse(
            sideEffectCoordinator: self.sideEffectCoordinator,
            state: nil,
            shouldPersist: self.shouldPersist)
    }
}

extension GraphResponse {

    func toAppResponse() -> AppResponse {
        // GraphResponse is just an in-place GraphState update;
        // never produces an updated AppState.
        AppResponse(
            sideEffectCoordinator: self.sideEffectCoordinator,
            state: nil,
            shouldPersist: self.shouldPersist)
    }
}
