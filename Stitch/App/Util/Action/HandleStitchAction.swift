//
//  HandleStitchAction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/18/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct EncodeCurrentProject: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.encodeCurrentProject()
        return .noChange
    }
}

struct ESCKeyPressed: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.escKeyPressed()
        return .noChange
    }
}

struct KeyCharacterPressBegan: StitchStoreEvent {
    @AppStorage(StitchAppSettings.IS_OPTION_REQUIRED_FOR_SHORTCUTS.rawValue) private var isOptionRequiredForShortcuts: Bool = Bool.defaultIsOptionRequiredForShortcuts
    let char: Character
    
    @MainActor
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.keyCharacterPressBegan(char: char,
                                     isOptionRequired: isOptionRequiredForShortcuts)
        return .noChange
    }
}


struct UndoEvent: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.undo()
        return .noChange
    }
}

struct RedoEvent: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.redo()
        return .noChange
    }
}

struct DisplayError: StitchStoreEvent {
    
    let error: StitchFileError
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.displayError(error: error)
        return .noChange
    }
}

struct ProjectDeleted: StitchStoreEvent {
    
    let document: StitchDocument
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.deleteProject(document: document)
        return .shouldPersist
    }
}

struct ProjectDeletedAndWillExitCurrentProject: StitchStoreEvent {
        
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.handleDeleteAndExitCurrentProject()
        return .shouldPersist
    }
}

struct UndoDeleteProject: StitchStoreEvent {
    let projectId: GraphId
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.undoDeleteProject(projectId: projectId)
        return .noChange
    }
}
