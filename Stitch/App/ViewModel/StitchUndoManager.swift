//
//  StitchUndoManager.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/9/22.
//

import Foundation
import StitchSchemaKit

/// Side effects to be dispatched by UndoManager during scenarios where state changes aren't enough. For example, a media import
/// needs a delete file action to undo the import.
/// For every undo effect, there must be a redo effect, which will likely be the same action thats being undone.
struct UndoFileEffects {
    let undoEvents: [Action]
    let redoEvents: [Action]
}

/// The class used for managing undo operations.
/// Note that `registerUndo` requires the parent object to be a class here.
final class StitchUndoManager: MiddlewareService {
    let undoManager = UndoManager()

    func createUndoEffects(undoEvents: Actions?,
                           redoEvents: Actions?) -> UndoFileEffects? {
        var undoFileEffects: UndoFileEffects?

        if let undoEvents = undoEvents {
            // Determine if any effect should be called after an undo, usually on file write/delete.
            // We make the dispatched action re-called as the redo event.
            //            let redoEvents = redoEvents ?? [action]
            let redoEvents = redoEvents ?? []

            undoFileEffects = UndoFileEffects(
                undoEvents: undoEvents,
                redoEvents: redoEvents)

        }

        return undoFileEffects
    }

    /// Creates redo effects
    @MainActor
    func processUndoFileEffects(_ undoFileEffects: UndoFileEffects?) -> UndoFileEffects? {
        var redoFileEffects: UndoFileEffects?

        if let undoFileEffects = undoFileEffects {
            undoFileEffects.undoEvents.forEach { action in
                dispatch(action)
            }

            // Make redo effects the opposite of undo effects
            redoFileEffects = UndoFileEffects(undoEvents: undoFileEffects.redoEvents,
                                              redoEvents: undoFileEffects.undoEvents)
        }

        return redoFileEffects
    }

    @MainActor
    func prepareAndSaveUndoHistory(prevDocument: StitchDocument,
                                   nextDocument: StitchDocument,
                                   undoEvents: Actions?,
                                   redoEvents: Actions?) {
        let undoFileEffects = createUndoEffects(undoEvents: undoEvents,
                                                redoEvents: redoEvents)

        // Defined undo events should not update undo stack trace with state
        if let undoFileEffects = undoFileEffects {
            self.saveUndoHistory(undoFileEffects: undoFileEffects)
        } else {
            self.saveUndoHistory(prevState: prevDocument,
                                 nextState: nextDocument,
                                 undoFileEffects: undoFileEffects)
        }
    }

    static func shouldUpdateUndo(willPersist: Bool,
                                 containsUndoEvents: Bool) -> Bool {

        // Assume all persisted actions will update undo stack
        willPersist ||
            // Update undo if there are any undo side effects defined
            containsUndoEvents
    }

    @MainActor
    private func saveUndoHistory(prevState: StitchDocument,
                                 nextState: StitchDocument,
                                 undoFileEffects: UndoFileEffects? = nil) {

        undoManager.registerUndo(withTarget: self) { _ in
            // Update state with previous when undo revoked
            dispatch(UndoManagerInvoked(newState: prevState))

            let redoFileEffects = self.processUndoFileEffects(undoFileEffects)

            // Register the redo action
            self.saveUndoHistory(prevState: nextState,
                                 nextState: prevState,
                                 undoFileEffects: redoFileEffects)
        }
    }

    @MainActor
    private func saveUndoHistory(undoFileEffects: UndoFileEffects) {
        undoManager.registerUndo(withTarget: self) { _ in
            dispatch(UndoManagerInvoked(newState: nil))

            if let redoFileEffects = self.processUndoFileEffects(undoFileEffects) {
                // Register the redo action
                self.saveUndoHistory(undoFileEffects: redoFileEffects)
            }
        }
    }
}

extension StitchStore {
    @MainActor
    func undoManagerInvoked(newState: StitchDocument? = nil) {
        guard let graph = self.currentGraph else {
            return
        }

        // HACK: see notes in `GraphUIState.adjustmentBarSessionId`
        graph.graphUI.adjustmentBarSessionId = .init(id: .init())

        // Update schema data
        if let newState = newState {
            graph.update(from: newState)

            // Persist graph
            graph.encodeProjectInBackground()
            
        }
    }
    
    /// Saves undo history of some graph using copies of StitchDocument.
    @MainActor
    func saveUndoHistory(oldState: StitchDocument,
                         newState: StitchDocument,
                         undoEvents: Actions? = nil,
                         redoEvents: Actions? = nil) {
        let undoManager = self.environment.undoManager
        let undoFileEffects = undoManager.createUndoEffects(undoEvents: undoEvents,
                                                            redoEvents: redoEvents)

        self.saveUndoHistory(oldState: oldState,
                             newState: newState,
                             undoFileEffects: undoFileEffects)
    }

    /// Saves undo history of some graph using copies of StitchDocument.
    @MainActor
    func saveUndoHistory(oldState: StitchDocument,
                         newState: StitchDocument,
                         undoFileEffects: UndoFileEffects?) {
        let undoManager = self.environment.undoManager

        undoManager.undoManager.registerUndo(withTarget: self) { _ in
            self.undoManagerInvoked(newState: oldState)

            let redoFileEffects = undoManager.processUndoFileEffects(undoFileEffects)

            // Register the redo action
            self.saveUndoHistory(oldState: newState,
                                 newState: oldState,
                                 undoFileEffects: redoFileEffects)
        }
    }

    /// Saves undo history using actions.
    @MainActor
    func saveUndoHistory(oldState: StitchDocument,
                         newState: StitchDocument,
                         undoEvents: [Action],
                         redoEvents: [Action]) {
        let undoManager = self.environment.undoManager

        undoManager.undoManager.registerUndo(withTarget: self) { _ in
            self.undoManagerInvoked(newState: oldState)

            undoEvents.forEach { undoEvent in
                dispatch(UndoEvent())
            }

            // Register the redo actions
            self.saveUndoHistory(oldState: newState,
                                 newState: oldState,
                                 undoEvents: redoEvents,
                                 redoEvents: undoEvents)
        }
    }

    /// Saves undo history using actions. Used for project deletion.
    @MainActor
    func saveUndoHistory(undoActions: [Action],
                         redoActions: [Action]) {
        let undoEvents: [@MainActor () -> ()] = undoActions.map { action in { self.environment.undoManager.safeDispatch(action) } }
        let redoEvents: [@MainActor () -> ()] = redoActions.map { action in { self.environment.undoManager.safeDispatch(action) } }
        
        self.saveUndoHistory(undoEvents: undoEvents,
                             redoEvents: redoEvents)
    }
    
    /// Saves undo history using actions. Used for project deletion.
    @MainActor
    func saveUndoHistory(undoEvents: [@MainActor () -> ()],
                         redoEvents: [@MainActor () -> ()]) {
        let undoManager = self.environment.undoManager.undoManager

        undoManager.registerUndo(withTarget: self) { _ in
            self.undoManagerInvoked()

            undoEvents.forEach { undoEvent in
                undoEvent()
            }

            // Make redo effects the opposite of undo effects
            let onRedoUndoEvents = redoEvents
            let onRedoRedoEvents = undoEvents

            // Register the redo action
            self.saveUndoHistory(undoEvents: onRedoUndoEvents,
                                 redoEvents: onRedoRedoEvents)
        }
    }
}

extension StitchStore {
    func undo() {
        self.environment.undoManager.undoManager.undo()
    }

    func redo() {
        self.environment.undoManager.undoManager.redo()
    }
}
