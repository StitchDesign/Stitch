//
//  ProjectCreatedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/26/22.
//

import Foundation
import StitchSchemaKit

// Creating a brand new project: empty state, no imported files
extension StitchStore {
    // fka `createNewProject`; but we need to indicate in some way, if not by type signature, that this is a side-effect
    @MainActor
    func createNewProjectSideEffect(from document: StitchDocument = .init(),
                                    isProjectImport: Bool) {
        let isPhoneDevice = StitchDocumentViewModel.isPhoneDevice
        
        Task(priority: .high) { [weak self] in
            guard let store = self else { return }
            await store.createNewProject(from: document,
                                         isProjectImport: isProjectImport,
                                         isPhoneDevice: isPhoneDevice)
        }
    }
        
    func createNewProject(from document: StitchDocument = .init(),
                          isProjectImport: Bool,
                          isPhoneDevice: Bool) async {
        do {
            try await self.documentLoader.createNewProject(
                from: document,
                isProjectImport: isProjectImport,
                isPhoneDevice: isPhoneDevice,
                store: self)
        } catch {
            log("StitchStore.createNewProject error: \(error.localizedDescription)")
            fatalErrorIfDebug(error.localizedDescription)
        }
    }

    /// Called in the event where project saved in iCloud is deleted
    /// from another device, but user opts to re-save.
    @MainActor
    func encodeCurrentProject(willUpdateUndoHistory: Bool = true) {
        guard let graphState = self.currentDocument?.visibleGraph else {
            return
        }

        graphState.encodeProjectInBackground(willUpdateUndoHistory: willUpdateUndoHistory)
    }
}
