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
    func projectCreatedAction() {
        Task { [weak self] in
            guard let documentLoader = self?.documentLoader else {
                return
            }
            
            let newDoc = try await documentLoader.installNewDocument()

            // Open doc
            await MainActor.run { [weak self] in
                self?.openProjectAction(from: newDoc)
            }
        }
    }

    @MainActor
    func openProjectAction(from document: StitchDocument) {
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
                store: store
            )
            
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
