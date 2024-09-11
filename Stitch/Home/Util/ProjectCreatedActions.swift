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
            let data = StitchDocumentData(document: newDoc,
                                          publishedDocumentComponents: [])

            // Open doc
            await MainActor.run { [weak self] in
                self?.openProjectAction(from: data)
            }
        }
    }

    @MainActor
    func openProjectAction(from data: StitchDocumentData) {
        // Get latest preview window size
        let previewDeviceString = UserDefaults.standard.string(forKey: DEFAULT_PREVIEW_WINDOW_DEVICE_KEY_NAME) ??
            PreviewWindowDevice.defaultPreviewWindowDevice.rawValue

        guard let previewDevice = PreviewWindowDevice(rawValue: previewDeviceString) else {
            #if DEBUG
            fatalError()
            #endif
            return
        }

        let graphState = GraphState(from: data,
                                    store: self)
        graphState.previewSizeDevice = previewDevice
        graphState.previewWindowSize = previewDevice.previewWindowDimensions
        self.navPath = [graphState]
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
