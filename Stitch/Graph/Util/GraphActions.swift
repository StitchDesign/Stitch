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
//extension StitchDocumentViewModel: DocumentEncodableDelegate {
//    @MainActor
//    func importedFilesDirectoryReceived(mediaFiles: [URL],
//                                        components: [StitchComponentData]) {
//        // Must initialize on main thread
//        self.graphStepManager.start()
//
//        self.graph.importedFilesDirectoryReceived(mediaFiles: mediaFiles,
//                                                  components: components)
//    }
//}
struct StitchComponentData {
    var draft: StitchComponent
    var published: StitchComponent
}

//
//struct StitchComponentData {
//    var draft: StitchComponent
//    let published: StitchComponent
//}

extension StitchComponentData: Identifiable {
    var id: UUID {
        get { self.draft.id }
        set(newValue) { self.draft.id = newValue }
    }
    
    var saveLocation: GraphSaveLocation {
        self.draft.saveLocation
    }
    
    var rootUrl: URL {
        self.draft.saveLocation
            .getRootDirectoryUrl(componentId: self.id)
    }
}

extension MasterComponentsDict {
    mutating func sync(with data: [StitchComponentData],
                       parentGraph: GraphState) {
        self.sync(with: data,
                  updateCallback: { viewModel, data in
//            viewModel.update(from: data)
        }) { data in
            StitchMasterComponent(componentData: data,
                                  parentGraph: parentGraph)
        }
    }
}

extension GraphState: DocumentEncodableDelegate {
    func willEncodeProject(schema: GraphEntity) { }
    
    func createSchema(from graph: GraphState) -> GraphEntity {
        self.createSchema()
    }
    
    func syncMediaFiles(_ mediaFiles: [URL]) {
        // Add default media and imported URLs
        let allMediaFiles = MediaLibrary.getDefaultLibraryDeps() + mediaFiles
        self.mediaLibrary = allMediaFiles.reduce(into: .init()) { result, url in
            result.updateValue(url, forKey: url.mediaKey)
        }
    }
    
    func importedFilesDirectoryReceived(mediaFiles: [URL],
                                        components: [StitchComponentData]) {
        // Set loading status to loaded
        self.libraryLoadingStatus = .loaded
        
        // Update draft and published components from disk
        self.components.sync(with: components,
                             parentGraph: self)

        // Add default media and imported URLs
        let allMediaFiles = MediaLibrary.getDefaultLibraryDeps() + mediaFiles
        self.mediaLibrary = allMediaFiles.reduce(into: .init()) { result, url in
            result.updateValue(url, forKey: url.mediaKey)
        }
        
        // Update GraphState with latest document data to calculate graph, now that media has been loaded
        // TODO: need a separate updater for graph
        
        // TODO: now get back here so we can update connections and stuff in components
        
//        self.documentDelegate?.update(from: <#T##StitchDocument#>)
        
//        self.visibleNodesViewModel.updateNodeSchemaData(newNodes: nodes,
//                                                        components: self.components,
//                                                        parentGraphPath: self.saveLocation)
        
//        self.updateSidebarListStateAfterStateChange()
//        
//        // TODO: why is this necessary?
//        _updateStateAfterListChange(
//            updatedList: self.sidebarListState,
////            expanded: self.sidebarExpandedItems,
//            expanded: self.getSidebarExpandedItems(),
//            graphState: self)
//        
//        // Calculate graph
//        self.initializeGraphComputation()
//        
//        // Initialize preview layers
//        self.updateOrderedPreviewLayers()
    }
   
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
