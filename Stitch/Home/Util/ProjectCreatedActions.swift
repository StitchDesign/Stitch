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
    @MainActor
    func createNewProject(from document: StitchDocument = .init()) {
        let isPhoneDevice = GraphUIState.isPhoneDevice
        
        Task(priority: .high) { [weak self] in
            guard let store = self else { return }
            await store.createNewProject(from: document,
                                         isPhoneDevice: isPhoneDevice)
        }
    }
    
    func createNewProject(from document: StitchDocument = .init(),
                          isPhoneDevice: Bool) async {
        do {
            try await self.documentLoader.createNewProject(from: document,
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
    func encodeCurrentProject() {
        guard let graphState = self.currentDocument?.visibleGraph else {
            return
        }

        graphState.encodeProjectInBackground()
    }
}
