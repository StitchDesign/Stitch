//
//  ReframeEvent.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/16/21.
//

import Foundation
import StitchSchemaKit

// TODO: Are there really Project-level responses? eg persistence?

typealias StitchStoreEvent = Action & StitchStoreActionHandler
typealias StitchDocumentEvent = Action & StitchDocumentEventHandler
typealias GraphEvent = Action & GraphActionHandler
typealias GraphEventWithResponse = Action & GraphActionWithResponseHandler
typealias ProjectEnvironmentEvent = Action & ProjectEnvironmentActionHandler
typealias AppEvent = Action & AppActionHandler
typealias AppEnvironmentEvent = Action & AppEnvironmentActionHandler
typealias GraphUIEvent = Action & GraphUIActionHandler
typealias ProjectAlertEvent = Action & ProjectAlertActionHandler
typealias FileManagerEvent = Action & FileManagerEffectHandler
//typealias LogEvent = Action & LogListenerEffectHandler
typealias UndoManagerEvent = Action & UndoManagerEffectHandler


protocol StitchStoreActionHandler {
    @MainActor
    func handle(store: StitchStore) -> ReframeResponse<NoState>
}

protocol StitchDocumentEventHandler {
    @MainActor
    func handle(state: StitchDocumentViewModel)
}

protocol GraphActionHandler {
    @MainActor
    func handle(state: GraphState)
}

protocol GraphActionWithResponseHandler {
    @MainActor
    func handle(state: GraphState) -> GraphResponse
}

protocol ProjectEnvironmentActionHandler {
    @MainActor
    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse
}

protocol AppActionHandler {
    @MainActor
    func handle(state: AppState) -> AppResponse
}

protocol AppEnvironmentActionHandler {
    @MainActor
    func handle(state: AppState,
                environment: StitchEnvironment) -> AppResponse
}

protocol GraphUIActionHandler {
    @MainActor
    func handle(state: GraphUIState)
}

protocol ProjectAlertActionHandler {
    @MainActor
    func handle(state: ProjectAlertState)
}

//protocol LogListenerEffectHandler {
//    @MainActor
//    func handle(logListener: LogListener,
//                fileManager: StitchFileManager) -> MiddlewareManagerResponse
//}

protocol FileManagerEffectHandler {
    @MainActor
    func handle(fileManager: StitchFileManager) -> MiddlewareManagerResponse
}

protocol UndoManagerEffectHandler {
    @MainActor
    func handle(undoManager: StitchUndoManager)
}
