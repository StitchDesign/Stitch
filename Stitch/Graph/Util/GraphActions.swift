//
//  GraphActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/21/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CloseGraph: StitchStoreEvent {
    
    @MainActor
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        log("CloseGraph called")
        
        // Clear temporary data
        try? FileManager.default.removeItem(at: StitchFileManager.tempDocumentResources)
        
        store.alertState = ProjectAlertState()

        // reset any project title edit;
        // the project-write-effect will update metadata for any in-progress title edit
        store.projectIdForTitleEdit = nil

        // Note: on iPad or Catalyst, `closeGraph` is usually dispatched when the project view disappears; but on iPhone we use a button to close the project.
        // It should be safe for us to redundantly set the navPath to empty (i.e. exit any project).
        store.navPath = []
        
        return .noChange
    }
}

extension GraphState: DocumentEncodableDelegate {
    @MainActor
    func updateOnUndo(schema: GraphEntity) {
        self.update(from: schema)
    }
    
    func willEncodeProject(schema: GraphEntity) {
        
        // Updates thumbnail
         if let document = self.documentDelegate {
             // Updates graph data when changed
             document.refreshGraphUpdaterId()
             
             document.encodeProjectInBackground(willUpdateUndoHistory: false)
         }
    }
    
    func createSchema(from graph: GraphState?) -> GraphEntity {
        self.createSchema()
    }
    
    @MainActor
    func syncMediaFiles(_ mediaFiles: [URL]) {
        // Add default media and imported URLs
        let allMediaFiles = MediaLibrary.getDefaultLibraryDeps() + mediaFiles
        self.mediaLibrary = allMediaFiles.reduce(into: .init()) { result, url in
            result.updateValue(url, forKey: url.mediaKey)
        }
    }
    
    @MainActor
    func importedFilesDirectoryReceived(mediaFiles: [URL],
                                        components: [StitchComponent]) {
        // Update draft and published components from disk
        self.components.sync(with: components,
                             parentGraph: self)

        // Add default media and imported URLs
        let allMediaFiles = MediaLibrary.getDefaultLibraryDeps() + mediaFiles
        self.mediaLibrary = allMediaFiles.reduce(into: .init()) { result, url in
            result.updateValue(url, forKey: url.mediaKey)
        }
    }
}

struct PreviewWindowDimensionsSwapped: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {
        log("PreviewWindowDimensionsSwapped called")

        let originalSize = state.previewWindowSize
        state.previewWindowSize.width = originalSize.height
        state.previewWindowSize.height = originalSize.width

        log("PreviewWindowDimensionsSwapped: state.previewWindowSize is now: \(state.previewWindowSize)")

        state.visibleGraph.encodeProjectInBackground()
    }
}

struct UpdatePreviewCanvasDimension: StitchDocumentEvent {
    let edit: String
    let isWidth: Bool
    let isCommitting: Bool

    func handle(state: StitchDocumentViewModel) {
        guard let number = Double(edit) else {
            // occurs when e.g. user enters a letter in the number
            //            log("UpdatePreviewCanvasDimension: did not have a valid number")
            return
        }

        // Only coerce to min dimension if we're committing
        let min = isCommitting ? CGFloat(PREVIEW_WINDOW_MIN_DIMENSION) : number
        let newDimension = CGFloat(max(number, min))

        if isWidth {
            state.previewWindowSize.width = newDimension
        } else {
            state.previewWindowSize.height = newDimension
        }

        if PreviewWindowDevice.allPreviewDeviceSizes.doesNotContain(state.previewWindowSize) {
            //            log("UpdatePreviewCanvasDimension: did not have known size, setting to custom...")
            state.previewSizeDevice = .custom
        }

        state.visibleGraph.encodeProjectInBackground()
    }
}

struct UpdatePreviewCanvasDevice: StitchDocumentEvent {
    let previewSize: PreviewWindowDevice

    func handle(state: StitchDocumentViewModel) {
        state.previewSizeDevice = previewSize

        // Only update dimensions if custom isn't selected
        if previewSize != .custom {
            state.previewWindowSize = previewSize.previewWindowDimensions
        }

        state.visibleGraph.encodeProjectInBackground()
    }
}
