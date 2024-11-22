//
//  GraphActions.swift
//  prototype
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

/// Starts a graph after first loading
extension GraphState {
    @MainActor
    func importedFilesDirectoryReceived(importedFilesDir: [URL],
                                        document: StitchDocument) {

        // Set loading status to loaded
        self.libraryLoadingStatus = .loaded

        // Add urls to library
        var mediaLibrary = importedFilesDir.reduce(MediaLibrary()) { partialResult, url in
            var partialResult = partialResult
            partialResult.updateValue(url, forKey: url.mediaKey)
            return partialResult
        }

        // Add default URLs
        MediaLibrary.getDefaultLibraryDeps().forEach { url in
            mediaLibrary.updateValue(url, forKey: url.mediaKey)
        }

        self.mediaLibrary = mediaLibrary

        // Must initialize on main thread!
        self.graphStepManager.start()

        // Update GraphState with latest document data to calculate graph, now that media has been loaded
        // TODO: need a separate updater for graph
        self.documentDelegate?.update(from: document)
        
        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
//            expanded: self.sidebarExpandedItems,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
                
        // Calculate graph
        self.documentDelegate?.initializeGraphComputation()
        
        // Initialize preview layers
        self.updateOrderedPreviewLayers()
    }
}

extension GraphState {
   
    func updateSidebarListStateAfterStateChange() {
        self.sidebarListState = getMasterListFrom(
            layerNodes: self.visibleNodesViewModel.layerNodes,
            // TODO: use real, persisted expanded sidebar items
            expanded: self.getSidebarExpandedItems(),
            orderedSidebarItems: self.orderedSidebarLayers)
    }
}

struct PreviewWindowDimensionsSwapped: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {
        log("PreviewWindowDimensionsSwapped called")

        let originalSize = state.previewWindowSize
        state.previewWindowSize.width = originalSize.height
        state.previewWindowSize.height = originalSize.width

        log("PreviewWindowDimensionsSwapped: state.previewWindowSize is now: \(state.previewWindowSize)")

        state.graph.encodeProjectInBackground()
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

        state.graph.encodeProjectInBackground()
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
