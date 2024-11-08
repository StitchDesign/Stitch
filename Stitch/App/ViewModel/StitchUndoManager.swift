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
    /// Saves undo history of some graph using copies of StitchDocument.
    @MainActor
    func saveUndoHistory<EncoderDelegate>(from encoderDelegate: EncoderDelegate,
                                          oldSchema: EncoderDelegate.CodableDocument,
                                          newSchema: EncoderDelegate.CodableDocument,
                                          undoEvents: Actions? = nil,
                                          redoEvents: Actions? = nil) where EncoderDelegate: DocumentEncodableDelegate {
        let undoCallback = { @Sendable @MainActor in
            guard let undoEvents = undoEvents else {
                return
            }
            
            for action in undoEvents {
                dispatch(action)
            }
        }
        
        let redoCallback = { @Sendable @MainActor in
            guard let redoEvents else {
                return
            }
            
            for action in redoEvents {
                dispatch(action)
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
        self.undoManager.undoManager.registerUndo(withTarget: encoderDelegate) { [weak self] delegate in
            Task(priority: .high) { @MainActor @Sendable [weak self, weak delegate] in
                guard let delegate = delegate else { return }
                
                await delegate.updateAsync(from: oldSchema)
                
                // Don't update undo history from this action
                self?.encodeCurrentProject(willUpdateUndoHistory: false)
    
                undoEffectsData?.undoCallback?()
            }
            
            // Hides adjustment bar, fixing issue where data becomes out of sync
            self?.currentDocument?.graphUI.adjustmentBarSessionId = .init()
            
            self?.saveUndoHistory(from: delegate,
                                  oldSchema: newSchema,
                                  newSchema: oldSchema,
                                  undoEffectsData: undoEffectsData?.createRedoEffects())
        }
    }
    
    /// Saves undo history using actions. Used for project deletion.
    @MainActor 
    func saveProjectDeletionUndoHistory(undoActions: [Action],
                                        redoActions: [Action]) {
        let undoEvents: [@Sendable @MainActor () -> ()] = undoActions.map { action in { self.environment.undoManager.safeDispatch(action) } }
        let redoEvents: [@Sendable @MainActor () -> ()] = redoActions.map { action in { self.environment.undoManager.safeDispatch(action) } }
        self.saveProjectDeletionUndoHistory(undoEvents: undoEvents,
                                            redoEvents: redoEvents)
    }
    
    /// Saves undo history using actions. Used for project deletion.
    func saveProjectDeletionUndoHistory(undoEvents: [@Sendable @MainActor () -> ()],
                                        redoEvents: [@Sendable @MainActor () -> ()]) {
        let undoManager = self.environment.undoManager.undoManager
        
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            undoEvents.forEach { undoEvent in
                Task(priority: .high) { @MainActor in
                    undoEvent()
                }
            }
            
            // Make redo effects the opposite of undo effects
            let onRedoUndoEvents = redoEvents
            let onRedoRedoEvents = undoEvents
            
            // Register the redo action
            self?.saveProjectDeletionUndoHistory(undoEvents: onRedoUndoEvents,
                                                 redoEvents: onRedoRedoEvents)
        }
    }
}

struct UndoEffectsData: Sendable {
    var undoCallback: (@MainActor @Sendable () -> Void)?
    var redoCallback: (@MainActor @Sendable () -> Void)?
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
