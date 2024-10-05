//
//  ProjectCreatedActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/26/22.
//

import Foundation
import StitchSchemaKit

// Creating a brand new project: empty state, no imported files
extension StitchStore {
    @MainActor
    func createNewProject(from document: StitchDocument = .init()) {
        Task(priority: .high) { [weak self] in
            guard let store = self else { return }
            await store.createNewProject(from: document)
        }
    }
    
    func createNewProject(from document: StitchDocument = .init()) async {
        do {
            try await self.documentLoader.createNewProject(from: document,
                                                           store: self)
        } catch {
            log("StitchStore.createNewProject error: \(error.localizedDescription)")
            fatalErrorIfDebug(error.localizedDescription)
        }
    }

    @MainActor
    func openProjectAction(projectLoader: ProjectLoader,
                           isNewProject: Bool = false) {
        guard let document = projectLoader.loadingDocument.document else {
            fatalErrorIfDebug()
            return
        }
        
        // Get latest preview window size
        let previewDeviceString = UserDefaults.standard.string(forKey: DEFAULT_PREVIEW_WINDOW_DEVICE_KEY_NAME) ??
            PreviewWindowDevice.defaultPreviewWindowDevice.rawValue
        
        let isPhoneDevice = GraphUIState.isPhoneDevice

        guard let previewDevice = PreviewWindowDevice(rawValue: previewDeviceString) else {
            fatalErrorIfDebug()
            return
        }

        Task { [weak self] in
            guard let store = self else { return }
            
            let document = await StitchDocumentViewModel(
                from: document,
                isPhoneDevice: isPhoneDevice,
                projectLoader: projectLoader,
                store: store
            )
            
            if isNewProject {
                document?.didDocumentChange = true // creates fresh thumbnail
            }
            
            await MainActor.run { [weak document, weak store] in
                guard let document = document else { return }
                
                document.previewSizeDevice = previewDevice
                document.previewWindowSize = previewDevice.previewWindowDimensions
                store?.navPath = [document]
            }
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
