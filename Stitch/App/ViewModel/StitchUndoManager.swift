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
        guard let document = self.currentDocument else {
            return
        }

        // HACK: see notes in `GraphUIState.adjustmentBarSessionId`
        document.graphUI.adjustmentBarSessionId = .init(id: .init())

        // Update schema data
        if let newState = newState {
            Task(priority: .high) {
                await document.update(from: newState)
            }

            // Persist graph
            document.visibleGraph.encodeProjectInBackground(wasUndo: true)
            
        }
    }
    
    /// Saves undo history of some graph using copies of StitchDocument.
    func saveUndoHistory<EncoderDelegate>(from encoderDelegate: EncoderDelegate,
                                          oldSchema: EncoderDelegate.CodableDocument,
                                          newSchema: EncoderDelegate.CodableDocument,
                                          undoEvents: Actions? = nil,
                                          redoEvents: Actions? = nil) where EncoderDelegate: DocumentEncodableDelegate {
        let undoCallback = {
            guard let undoEvents = undoEvents else {
                return
            }
            
            // TODO: do we need dispatch?
            DispatchQueue.main.async {
                for action in undoEvents {
                    dispatch(action)
                }
            }
        }
        
        let redoCallback = {
            guard let redoEvents else {
                return
            }
            
            DispatchQueue.main.async {
                for action in redoEvents {
                    dispatch(action)
                }
            }
        }
        
        return self.saveUndoHistory(from: encoderDelegate,
                                    oldSchema: oldSchema,
                                    newSchema: newSchema,
                                    undoEffectsData: .init(undoCallback: undoCallback,
                                                           redoCallback: redoCallback))
    }
    
    func saveUndoHistory<EncoderDelegate>(from encoderDelegate: EncoderDelegate,
                                          oldSchema: EncoderDelegate.CodableDocument,
                                          newSchema: EncoderDelegate.CodableDocument,
                                          undoEffectsData: UndoEffectsData? = nil) where EncoderDelegate: DocumentEncodableDelegate {
        
        // Update undo
        self.undoManager.undoManager.registerUndo(withTarget: encoderDelegate) { delegate in
            delegate.updateOnUndo(schema: oldSchema)
            
            undoEffectsData?.undoCallback?()
            
            self.saveUndoHistory(from: delegate,
                                 oldSchema: newSchema,
                                 newSchema: oldSchema,
                                 undoEffectsData: undoEffectsData?.createRedoEffects())
        }
    }

    /// Saves undo history of some graph using copies of StitchDocument.
    @MainActor
    func saveUndoHistory(oldState: StitchDocument,
                         newState: StitchDocument,
                         undoFileEffects: UndoFileEffects? = nil) {
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

struct UndoEffectsData {
    var undoCallback: (() -> Void)?
    var redoCallback: (() -> Void)?
}

extension UndoEffectsData {
    func createRedoEffects() -> UndoEffectsData {
        .init(undoCallback: redoCallback,
              redoCallback: undoCallback)
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
