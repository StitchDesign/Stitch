//
//  MediaActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import RealityKit

// Actions pertaining to media, eg.
// - importing an image, video or sound file
// - picking an image from

extension StitchStore {
    /// Given a user selection, determines the side effects needed to import media files.
    /// Source: https://www.hackingwithswift.com/forums/swiftui/looking-for-help-how-to-select-and-open-an-existing-data-file-with-a-document-browser/3953
    @MainActor
    func mediaFilesImportedToNewNode(selectedFiles: [URL],
                                     centerPostion: CGPoint) {
        // Toggle alert state
        self.alertState.fileImportModalState = .notImporting

        guard let graphState = self.currentDocument?.visibleGraph else {
            self.alertState.stitchFileError = .currentProjectNotFound
            return
        }

        // If we have a drop location,
        // adjust it to be a multiple of grid square length.
        let droppedLocation = adjustPositionToMultipleOf(centerPostion)

        for fileURL in selectedFiles {
            // Show error if media type is unknown
            if fileURL.getMediaType() == nil {
                self.alertState.stitchFileError = .mediaFileUnsupported(fileURL.pathExtension)
            }

            graphState.documentEncoderDelegate?
                .importFileToNewNode(fileURL: fileURL, droppedLocation: droppedLocation)
        }
    }

    @MainActor
    func mediaFilesImportedToExistingNode(selectedFiles: [URL],
                                          nodeImportPayload: NodeMediaImportPayload) {
        //        log("MediaFilesImportedToExistingNode called: selectedFiles: \(selectedFiles)")
        //        log("MediaFilesImportedToExistingNode called: nodeImportPayload: \(nodeImportPayload)")
        //        log("MediaFilesImportedToExistingNode called: nodeImportPayload.mediaFormat: \(nodeImportPayload.mediaFormat)")

        // Toggle alert state
        self.alertState.fileImportModalState = .notImporting

        guard let graphState = self.currentDocument?.visibleGraph else {
            self.alertState.stitchFileError = .currentProjectNotFound
            return
        }

        for fileURL in selectedFiles {
            //            log("MediaFilesImportedToExistingNode: fileURL: \(fileURL)")
            // Check if selected media is supported by destination node
            guard fileURL.supports(mediaFormat: nodeImportPayload.mediaFormat) else {
                //                log("fileURL not supported ...: \(fileURL)")
                self.alertState.stitchFileError = .mediaFileUnsupportedForNode(fileExt: fileURL.pathExtension)
                return
            }

            graphState.documentEncoderDelegate?
                .importFileToExistingNode(fileURL: fileURL, nodeImportPayload: nodeImportPayload)
        }
    }
}

/// Called when a media import from the top bar file picker or drag-and-drop event happens.
extension DocumentEncodable {
    @MainActor
    func importFileToNewNode(fileURL: URL, droppedLocation: CGPoint) {
        let copyResult = self.copyToMediaDirectory(
            originalURL: fileURL,
            forRecentlyDeleted: false)
        
        switch copyResult {
        case .success(let newURL):
            dispatch(MediaCopiedToNewNode(url: newURL, location: droppedLocation))
            
        case .failure(let error):
            dispatch(DisplayError(error: error))
        }
    }
    
    /// Called when media is imported from a patch node's file picker.
    @MainActor
    func importFileToExistingNode(fileURL: URL, nodeImportPayload: NodeMediaImportPayload) {
        let copyResult = self.copyToMediaDirectory(originalURL: fileURL,
                                                   forRecentlyDeleted: false)
        switch copyResult {
        case .success(let newURL):
            dispatch(MediaCopiedToExistingNode(url: newURL,
                                               nodeMediaImportPayload: nodeImportPayload))
        case .failure(let error):
            dispatch(DisplayError(error: error))
        }
    }
    
    /// Called when recently-deleted media is undo-ed.
    func undoDeletedMedia(mediaKey: MediaKey) -> URLResult {
        // Look for media in expected "recently deleted" location"
        guard let expectedMediaURL = self.getFolderUrl(for: .media,
                                                       isTemp: true)?
            .appendingPathComponent(mediaKey.filename)
            .appendingPathExtension(mediaKey.fileExtension) else {
            return .failure(.persistenceDisabled)
        }
        
        // We import back to the current opened project
        return self.copyToMediaDirectory(originalURL: expectedMediaURL,
                                         forRecentlyDeleted: false)
    }
}

extension GraphState {
    /// Creates a new node for some imported media. This is called either from drag-and-drop or from the top bar file picker.
    @MainActor
    func mediaCopiedToNewNode(newURL: URL,
                              nodeLocation: CGPoint,
                              store: StitchStore) {
        guard let document = store.currentDocument else {
            return
        }
        
        // Ensure media is supported
        guard let mediaType = newURL.getMediaType() else {
            store.alertState.stitchFileError = .mediaFileUnsupported(newURL.pathExtension)
            return
        }

        let droppedLocation = nodeLocation
        //        let localPosition = self.localPosition
        //        let graphScale = document.graphMovement.zoomData
        //
        //        let originalNodeLocation = nodeLocation.toCGSize

        // Add media key to computed node state
        self.mediaLibrary.updateValue(newURL, forKey: newURL.mediaKey)

        // TODO: place media where it was dropped by factoring out zoom and offset etc.
        // Adjust dropped location based on graph view offset and scale
//        droppedLocation = factorOutGraphOffsetAndScale(
//            location: originalNodeLocation.toCGPoint,
//            graphOffset: localPosition,
//            graphScale: graphScale,
//            deviceScreen: self.frame)


        // Create the node if no destination input specified
        let newNodeId = NodeId()

        switch createPatchNode(from: newURL,
                               mediaType: mediaType,
                               nodeId: newNodeId,
                               patch: nil,
                               position: droppedLocation.toCGSize,
                               zIndex: self.highestZIndex + 1,
                               activeIndex: document.activeIndex,
                               graphDelegate: self) {
        case .success(let patchNode):
            guard let patchViewModel = patchNode.patchNode else {
                fatalErrorIfDebug()
                return
            }

            // Update group state if node created inside group
            patchViewModel.parentGroupNodeId = document.groupNodeFocused?.asNodeId

            // Must also add the media patch node to graphState,
            // so that it can be found when we evaluate the graph.
            self.updatePatchNode(patchNode)

        case .failure(let error):
            store.alertState.stitchFileError = error
        }

        self.scheduleForNextGraphStep(newNodeId)
        self.encodeProjectInBackground()
    }
    
    /// Takes some imported media and applies it directly to the input of some node.
    @MainActor
    func mediaCopiedToExistingNode(nodeImportPayload: NodeMediaImportPayload,
                                   newURL: URL,
                                   activeIndex: ActiveIndex) {
        let mediaKey = newURL.mediaKey
        let destinationInputs = nodeImportPayload.destinationInputs
        
        for destinationInput in destinationInputs {
            
            let nodeId = destinationInput.nodeId

            // Add media key to computed node state
            self.mediaLibrary.updateValue(newURL, forKey: newURL.mediaKey)

            // Can now be patch- OR layer-node
            guard let existingNode = self.getNode(nodeId) else {
                dispatch(DisplayError(error: .mediaCopiedFailed))
                return
            }

            // If existing node already contains imported media, then we need to delete the old media
            // EXCEPT if it's a loop builder node which can hold multiple media
            if existingNode.kind != .patch(.loopBuilder) {
                existingNode.inputs.findImportedMediaKeys().forEach { mediaKey in
                    if mediaLibrary.get(mediaKey) != newURL {
                        self.checkToDeleteMedia(mediaKey, from: existingNode.id)
                    }
                }                
            }

            let newMedia = AsyncMediaValue(mediaKey: mediaKey)
            let portValue = PortValue.asyncMedia(newMedia)

            self.mediaInputEditCommitted(input: destinationInput,
                                         value: portValue,
                                         activeIndex: activeIndex)

            self.encodeProjectInBackground()       
        } // for destinationInput in ...        
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func realityViewCreatedWithoutCamera(graph: GraphState,
                                         nodeId: NodeId,
                                         realityCameraDirection: CameraDirection) {
        if self.cameraFeedManager?.isLoading ?? false {
            log("RealityViewCreatedWithoutCamera: already loading")
            return
        }
        
        // Change camera settings if reality node uses different direction
        if self.cameraSettings.direction != realityCameraDirection {
            self.cameraSettings.direction = realityCameraDirection
        }

        self.refreshCamera(for: .layer(.realityView),
                           graph: graph,
                           newNode: nodeId)
    }
}

extension StitchDocumentViewModel {
    func teardownSingleton(keyPath: MediaManagerSingletonKeyPath) {
        self[keyPath: keyPath] = nil
    }
}

extension GraphState {
    @MainActor
    func recalculateGraphForMedia<MediaEvalResult>(result: MediaEvalResult,
                                                   nodeId: NodeId,
                                                   loopIndex: Int) where MediaEvalResult: MediaEvalResultable{
        guard let node = self.getNode(nodeId) else {
            log("recalculateGraph: AsyncMediaImpureEvalOpResult: could not retrieve node \(nodeId)")
            return
        }
        
        guard let mediaObserver = node.ephemeralObservers?[safe: loopIndex] as? MediaEvalOpObservable else {
            // Valid failure if loop builder removes input
//            fatalErrorIfDebug()
            return
        }
        
        mediaObserver.computedMedia = result.media
        
        // Disable loading state
        // Important to not dispatch main actor task as this creates race conditions
        mediaObserver.currentLoadingMediaId = nil
        
        self.recalculateGraphForMedia(outputValues: result.valueResult,
                                      media: result.media,
                                      nodeId: nodeId,
                                      loopIndex: loopIndex)
    }
    
    @MainActor
    /// Recalculates the graph when the **outputs** of a node need to be updated.
    /// This updates at a particular loop index rather than all values.
    /// NOTE: we DO NOT want to run the eval of the media node itself again; we just want to evaluate any downstream nodes
    func recalculateGraphForMedia(outputValues: AsyncMediaOutputs,
                                  media: GraphMediaValue?,
                                  nodeId: NodeId,
                                  loopIndex: Int) {
        let graph = self
        let outputValues = outputValues
        var nodeIdsToRecalculate = NodeIdSet()
        
        guard let node = graph.getNode(nodeId) else {
            log("recalculateGraph: AsyncMediaImpureEvalOpResult: could not retrieve node \(nodeId)")
            return
        }
        
        let outputsToUpdate = node.outputs
        
        // List of new outputvalues must match the node's
        guard outputValues.count == outputsToUpdate.count else {
            log("recalculateGraph: AsyncMediaImpureEvalOpResult: incorrect output count for node \(nodeId)")
#if DEV_DEBUG
            fatalError()
#endif
            return
        }
        
        switch outputValues {
            
        case .byIndex(let portValues):
            
            graph.updateOutputs(at: loopIndex,
                                node: node,
                                portValues: portValues,
                                media: media)
            
        case .all(let portValuesList):
            var changedDownstreamNodes = NodeIdSet()
            
            // portValuesList is the full outputs etc.;
            // set new outputs in node
            node.updateOutputsObservers(newValuesList: portValuesList, graph: graph)
            
            // We just manually set new outputs on the media node.
            // Now we need to flow those new outputs to any downstream nodes,
            // WITHOUT, however, running the media node's eval again.
            guard let downstreamNodeIds = graph.shallowDownstreamNodes.get(nodeId) else {
                fatalErrorIfDebug()
                return
            }
            
            nodeIdsToRecalculate = nodeIdsToRecalculate.union(downstreamNodeIds)
            
            // Flow new outputs to downstream nodes
            node.outputs.enumerated().forEach { index, values in
                let downstreamInputs = graph.updateDownstreamInputs(
                    sourceNode: node,
                    upstreamOutputValues: values,
                    mediaList: [media],
                    upstreamOutputChanged: true, // Okay to treat a media change as always some output changing?
                    outputCoordinate: .init(portId: index, nodeId: node.id))
                let downstreamNodes = Set(downstreamInputs.map(\.nodeId)).toSet
                
                changedDownstreamNodes = changedDownstreamNodes.union(downstreamNodes)
            }
            
            // Recalculate downstream patch nodes after values are updated
            self.scheduleForNextGraphStep(changedDownstreamNodes)
        }
        
        // Update all output fields
        // Fixes issue where async race condition may not properly update fields for image nodes
        self.portsToUpdate.insert(.allOutputs(node.id))
    }
    
    @MainActor
    func mediaPickerChanged(selectedValue: PortValue,
                            mediaType: NodeMediaSupport,
                            rowObserver: InputNodeRowObserver,
                            activeIndex: ActiveIndex,
                            isFieldInsideLayerInspector: Bool) {
        // Commit the new media to the selector input
        self.handleInputEditCommitted(input: rowObserver,
                                      value: selectedValue,
                                      activeIndex: activeIndex,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        
        self.encodeProjectInBackground()
    }
    
    @MainActor
    func mediaPickerNoneChanged(rowObserver: InputNodeRowObserver,
                                node: NodeViewModel,
                                activeIndex: ActiveIndex,
                                isFieldInsideLayerInspector: Bool) {
        let emptyPortValue = PortValue.asyncMedia(nil)
        self.handleInputEditCommitted(input: rowObserver,
                                      value: emptyPortValue,
                                      activeIndex: activeIndex,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        
        // Empty media in input
        node.updateInputMedia(inputCoordinate: rowObserver.id,
                              mediaList: [nil])
        
        self.encodeProjectInBackground()
    }
}

// TODO: video-import node should also show resource size output?
/// Creates node specifically from some imported media URL.
@MainActor
func createPatchNode(from importedMediaURL: URL,
                     mediaType: SupportedMediaFormat,
                     nodeId: NodeId,
                     patch: Patch?,
                     position: CGSize,
                     zIndex: Double,
                     activeIndex: ActiveIndex,
                     graphDelegate: GraphState?) -> PatchNodeResult {
    let asyncMedia = AsyncMediaValue(
        id: UUID(),
        dataType: .source(importedMediaURL.mediaKey),
        label: importedMediaURL.filename)

    guard let node = mediaType.nodeKind.graphNode?.createViewModel(id: nodeId,
                                                                   position: position.toCGPoint,
                                                                   zIndex: zIndex,
                                                                   graphDelegate: graphDelegate) else {
        log("createPatchNode: unknown file encountered with extension \(importedMediaURL.pathExtension)")
        return .failure(.mediaFileUnsupported(importedMediaURL.pathExtension))
    }

    // Import nodes always use first input
    node.getInputRowObserver(0)?.updateValuesInInput([.asyncMedia(asyncMedia)])
    return .success(node)
}
