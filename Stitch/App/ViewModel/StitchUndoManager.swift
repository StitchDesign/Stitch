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
    
    /// Saves undo history using actions. Used for project deletion.
    @MainActor 
    func saveProjectDeletionUndoHistory(undoActions: [Action],
                                        redoActions: [Action]) {
        let undoEvents: [@MainActor () -> ()] = undoActions.map { action in { self.environment.undoManager.safeDispatch(action) } }
        let redoEvents: [@MainActor () -> ()] = redoActions.map { action in { self.environment.undoManager.safeDispatch(action) } }
        self.saveProjectDeletionUndoHistory(undoEvents: undoEvents,
                                            redoEvents: redoEvents)
    }
    
    /// Saves undo history using actions. Used for project deletion.
    @MainActor
    func saveProjectDeletionUndoHistory(undoEvents: [@MainActor () -> ()],
                                        redoEvents: [@MainActor () -> ()]) {
        let undoManager = self.environment.undoManager.undoManager
        
        undoManager.registerUndo(withTarget: self) { _ in
            undoEvents.forEach { undoEvent in
                undoEvent()
            }
            
            // Make redo effects the opposite of undo effects
            let onRedoUndoEvents = redoEvents
            let onRedoRedoEvents = undoEvents
            
            // Register the redo action
            self.saveProjectDeletionUndoHistory(undoEvents: onRedoUndoEvents,
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
