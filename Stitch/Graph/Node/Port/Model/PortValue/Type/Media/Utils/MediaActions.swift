//
//  MediaActions.swift
//  prototype
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
                                     centerPostion: CGPoint) async {
        // Toggle alert state
        self.alertState.fileImportModalState = .notImporting

        guard let graphState = self.currentGraph else {
            self.alertState.stitchFileError = .currentProjectNotFound
            return
        }

        // If we have a drop location,
        // adjust it to be a multiple of grid square length.
        let droppedLocation = adjustPositionToMultipleOf(centerPostion)

        for fileURL in selectedFiles {
            // Show error if media type is unknown
            if fileURL.getMediaType() == .unknown {
                self.alertState.stitchFileError = .mediaFileUnsupported(fileURL.pathExtension)
            }

            await graphState.importFileToNewNode(fileURL: fileURL, droppedLocation: droppedLocation)
        }
    }

    @MainActor
    func mediaFilesImportedToExistingNode(selectedFiles: [URL],
                                          nodeImportPayload: NodeMediaImportPayload) async {
        //        log("MediaFilesImportedToExistingNode called: selectedFiles: \(selectedFiles)")
        //        log("MediaFilesImportedToExistingNode called: nodeImportPayload: \(nodeImportPayload)")
        //        log("MediaFilesImportedToExistingNode called: nodeImportPayload.mediaFormat: \(nodeImportPayload.mediaFormat)")

        // Toggle alert state
        self.alertState.fileImportModalState = .notImporting

        guard let graphState = self.currentGraph else {
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

            await graphState.importFileToExistingNode(fileURL: fileURL, nodeImportPayload: nodeImportPayload)
        }
    }
}

/// Called when a media import from the top bar file picker or drag-and-drop event happens.
extension GraphState {
    @MainActor
    func importFileToNewNode(fileURL: URL, droppedLocation: CGPoint) async {
        let copyResult = await StitchFileManager.copyToMediaDirectory(
            originalURL: fileURL,
            in: self.createSchema(),
            forRecentlyDeleted: false)

        await MainActor.run {
            switch copyResult {
            case .success(let newURL):
                dispatch(MediaCopiedToNewNode(url: newURL, location: droppedLocation))
                
            case .failure(let error):
                dispatch(DisplayError(error: error))
            }
        }
    }

    /// Called when media is imported from a patch node's file picker.
    @MainActor
    func importFileToExistingNode(fileURL: URL, nodeImportPayload: NodeMediaImportPayload) async {
        let copyResult = await StitchFileManager.copyToMediaDirectory(originalURL: fileURL,
                                                                      in: self.createSchema(),
                                                                      forRecentlyDeleted: false)
        await MainActor.run {
            switch copyResult {
            case .success(let newURL):
                dispatch(MediaCopiedToExistingNode(url: newURL,
                                                   nodeMediaImportPayload: nodeImportPayload))
            case .failure(let error):
                dispatch(DisplayError(error: error))
            }
        }
    }

    /// Called when recently-deleted media is undo-ed.
    @MainActor
    func undoDeletedMedia(mediaKey: MediaKey) async -> URLResult {
        let document = self.createSchema()

        // Look for media in expected "recently deleted" location"
        let expectedMediaURL = document.getImportedFilesURL(forRecentlyDeleted: true)
            .appendingPathComponent(mediaKey.filename)
            .appendingPathExtension(mediaKey.fileExtension)

        // We import back to the current opened project
        return await StitchFileManager.copyToMediaDirectory(originalURL: expectedMediaURL,
                                                            in: document,
                                                            forRecentlyDeleted: false)
    }

    /// Creates a new node for some imported media. This is called either from drag-and-drop or from the top bar file picker.
    @MainActor
    func mediaCopiedToNewNode(newURL: URL,
                              nodeLocation: CGPoint,
                              store: StitchStore) {
        var droppedLocation = nodeLocation
        let localPosition = self.localPosition
        let graphScale = self.graphMovement.zoomData.zoom

        let originalNodeLocation = nodeLocation.toCGSize

        // Add media key to computed node state
        self.mediaLibrary.updateValue(newURL, forKey: newURL.mediaKey)

        // Adjust dropped location based on graph view offset and scale
        droppedLocation = factorOutGraphOffsetAndScale(
            location: originalNodeLocation.toCGPoint,
            graphOffset: localPosition,
            graphScale: graphScale,
            deviceScreen: self.graphUI.frame)

        let mediaType = newURL.getMediaType()

        // Create the node if no destination input specified
        let newNodeId = NodeId()

        switch createPatchNode(from: newURL,
                               mediaType: mediaType,
                               nodeId: newNodeId,
                               patch: nil,
                               position: droppedLocation.toCGSize,
                               zIndex: self.highestZIndex + 1,
                               activeIndex: self.activeIndex,
                               graphDelegate: self) {
        case .success(let patchNode):
            guard let patchViewModel = patchNode.patchNode else {
                #if DEBUG
                fatalError()
                #endif
                return
            }

            // Update group state if node created inside group
            patchViewModel.parentGroupNodeId = self.graphUI.groupNodeFocused?.asNodeId

            // Must also add the media patch node to graphState,
            // so that it can be found when we evaluate the graph.
            self.updatePatchNode(patchNode)

        case .failure(let error):
            store.alertState.stitchFileError = error
        }

        self.calculate(newNodeId)
        self.encodeProjectInBackground()
    }
}

extension GraphState {
    /// Takes some imported media and applies it directly to the input of some node.
    @MainActor
    func mediaCopiedToExistingNode(nodeImportPayload: NodeMediaImportPayload,
                                   newURL: URL,
                                   store: StitchStore) {
        let mediaKey = newURL.mediaKey
        let destinationInput = nodeImportPayload.destinationInput
        let nodeId = destinationInput.nodeId

        // Add media key to computed node state
        self.mediaLibrary.updateValue(newURL, forKey: newURL.mediaKey)

        // Can now be patch- OR layer-node
        guard let existingNode = self.getNodeViewModel(nodeId),
        let mediaObserver = existingNode.ephemeralObservers?.first as? MediaEvalOpObserver else {
            dispatch(DisplayError(error: .mediaCopiedFailed))
            return
        }

        existingNode.inputs.findImportedMediaKeys().forEach { mediaKey in
            // If existing node already contains imported media, then we need to delete the old media
            if mediaLibrary.get(mediaKey) != newURL {
                self.mediaLibrary.removeValue(forKey: mediaKey)

                Task { [weak self] in
                    await self?.documentEncoder.deleteMediaFromNode(mediaKey: mediaKey)
                }
            }
        }
        
        // Create async task to load media
        Task { [weak self, weak store] in
            guard let graph = self,
                  let store = store,
                  let newMedia = await MediaEvalOpCoordinator
                .createMediaValue(from: mediaKey,
                                  isComputedCopy: false,
                                  mediaId: .init(),
                                  graphDelegate: graph,
                                  nodeId: nodeId) else {
                return
            }
            
            store.inputEditCommitted(input: destinationInput,
                                     value: newMedia.portValue)
            
            // Persist project once media has loaded
            store.encodeCurrentProject()
        }

        // Nil value for now while media loads
        let portValue = PortValue.asyncMedia(nil)

        store.inputEditCommitted(input: destinationInput,
                                 value: portValue)
    }
}

extension NodeRowObserver {
    @MainActor
    func mediaObjectCreationFailed(loopIndex: Int) {
        guard self.allLoopedValues.count > loopIndex else {
            return
        }
        
        self.allLoopedValues[loopIndex] = .asyncMedia(nil)
    }
}

struct RealityViewCreatedWithoutCamera: GraphEvent {
    let nodeId: NodeId

    func handle(state: GraphState) {
        if state.cameraFeedManager?.isLoading ?? false {
            log("RealityViewCreatedWithoutCamera: already loading")
            return
        }

        state.refreshCamera(for: .layer(.realityView), newNode: nodeId)
    }
}

struct SingletonMediaTeardown: GraphEvent {
    let keyPath: MediaManagerSingletonKeyPath

    func handle(state: GraphState) {
        state.teardownSingleton(keyPath: keyPath)
    }
}

extension GraphState {
    func teardownSingleton(keyPath: MediaManagerSingletonKeyPath) {
        self[keyPath: keyPath] = nil
    }
}

extension GraphState {
    @MainActor
    /// Recalculates the graph when the **outputs** of a node need to be updated.
    /// This updates at a particular loop index rather than all values.
    /// NOTE: we DO NOT want to run the eval of the media node itself again; we just want to evaluate any downstream nodes
    func recalculateGraph(outputValues: AsyncMediaOutputs,
                          nodeId: NodeId,
                          loopIndex: Int) {
        let graph = self
        let outputValues = outputValues
        var nodeIdsToRecalculate = NodeIdSet()
        var effects = SideEffects()
        
        guard let node = graph.getNodeViewModel(nodeId) else {
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
                                portValues: portValues)
            
            effects += portValues.enumerated().flatMap { portId, value in
                value.getPulseReversionEffects(nodeId: nodeId,
                                               portId: portId,
                                               graphTime: graph.graphStepState.graphTime)
            }
            
            effects.processEffects()
            
        case .all(let portValuesList):
            var changedDownstreamNodes = NodeIdSet()
            
            // portValuesList is the full outputs etc.;
            // set new outputs in node
            node.updateOutputsObservers(newValuesList: portValuesList,
                                        activeIndex: graph.activeIndex)
            
            effects += portValuesList
                .getPulseReversionEffects(nodeId: nodeId,
                                          graphTime: graph.graphStepState.graphTime)
            
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
                changedDownstreamNodes = changedDownstreamNodes.union(
                    graph.updateDownstreamInputs(
                    flowValues: values,
                    outputCoordinate: .init(portId: index, nodeId: node.id))
                )
            }
            
            // Recalculate downstream patch nodes after values are updated
            self.calculate(changedDownstreamNodes)
            
            effects.processEffects()
        }
    }
}

struct MediaPickerChanged: ProjectEnvironmentEvent {
    let selectedValue: PortValue
    let mediaType: SupportedMediaFormat
    let input: InputCoordinate

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        // Commit the new media to the selector input
        graphState.inputEditCommitted(input: input,
                                      value: selectedValue)
        
        return .persistenceResponse
    }
}

struct MediaPickerNoneChanged: ProjectEnvironmentEvent {
    let input: InputCoordinate

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        let emptyPortValue = PortValue.asyncMedia(nil)
        graphState.inputEditCommitted(input: input,
                                      value: emptyPortValue)
        
        return .persistenceResponse
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
                     graphDelegate: GraphDelegate?) -> PatchNodeResult {
    let asyncMedia = AsyncMediaValue(
        id: UUID(),
        dataType: .source(importedMediaURL.mediaKey),
        _mediaObject: nil)

    guard let node = mediaType.nodeKind?.graphNode?.createViewModel(id: nodeId,
                                                                    position: position.toCGPoint,
                                                                    zIndex: zIndex,
                                                                    activeIndex: activeIndex,
                                                                    graphDelegate: graphDelegate) else {
        log("createPatchNode: unknown file encountered with extension \(importedMediaURL.pathExtension)")
        return .failure(.mediaFileUnsupported(importedMediaURL.pathExtension))
    }

    // Import nodes always use first input
    node.getInputRowObserver(0)?.updateValues([.asyncMedia(asyncMedia)],
                                              activeIndex: activeIndex,
                                              isVisibleInFrame: true)
    return .success(node)
}
