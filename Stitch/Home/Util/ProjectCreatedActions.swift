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

        guard let previewDevice = PreviewWindowDevice(rawValue: previewDeviceString) else {
            fatalErrorIfDebug()
            return
        }

        let document = StitchDocumentViewModel(from: document,
                                               store: self)
        document.previewSizeDevice = previewDevice
        document.previewWindowSize = previewDevice.previewWindowDimensions
        self.navPath = [document]
    }

    /// Called in the event where project saved in iCloud is deleted
    /// from another device, but user opts to re-save.
    @MainActor
    func encodeCurrentProject() {
        guard let graphState = self.currentGraph else {
            return
        }

        graphState.encodeProjectInBackground()
    }
}
