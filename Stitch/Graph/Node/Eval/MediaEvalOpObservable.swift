//
//  MediaEvalOpObservable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/24.
//

import Foundation
import StitchEngine
import StitchSchemaKit
import SwiftUI

/// Creates observable class with presentable media.
protocol MediaEvalOpViewable: NodeEphemeralObservable, Sendable {
    var mediaViewModel: MediaViewModel { get }
}

protocol MediaEvalOpObservable: NodeEphemeralObservable, MediaEvalOpViewable, Sendable {
    @MainActor var nodeDelegate: NodeViewModel? { get set }
    
    @MainActor var currentLoadingMediaId: UUID? { get set }
    
    var mediaActor: MediaEvalOpCoordinator { get }
}

final class MediaReferenceObserver: MediaEvalOpViewable {
    let mediaViewModel: MediaViewModel
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
    
    func onPrototypeRestart(document: StitchDocumentViewModel) { }
}

final class MediaEvalOpObserver: MediaEvalOpObservable {
    let mediaViewModel: MediaViewModel
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeViewModel?
    internal let mediaActor = MediaEvalOpCoordinator()
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
}

final class VisionOpObserver: MediaEvalOpObservable {
    let mediaViewModel: MediaViewModel
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeViewModel?
    internal let mediaActor = MediaEvalOpCoordinator()
    let coreMlActor = VisionOpActor()
        
    @MainActor init() {
        self.mediaViewModel = .init()
    }

    func onPrototypeRestart(document: StitchDocumentViewModel) { }
}

final class ImageClassifierOpObserver: MediaEvalOpObservable {
    let mediaViewModel: MediaViewModel
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeViewModel?
    internal let mediaActor = MediaEvalOpCoordinator()
    let coreMlActor = ImageClassifierActor()
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
    
    func onPrototypeRestart(document: StitchDocumentViewModel) { }
}

extension MediaEvalOpObserver {
    @MainActor func onPrototypeRestart(document: StitchDocumentViewModel) {
        // MARK: commenting out to fix flashing media, which seems to still reset properly
//        self.resetMedia()
        
        // MARK: below functionality keeps objects in place, which would make restarts less jarring should be an issue again
//        switch currentMedia?.mediaObject {
//        case .video(let videoPlayer):
//            videoPlayer.resetPlayer()
//        case .soundfile(let soundPlayer):
//            soundPlayer.delegate.setJumpTime(.zero)
//        case .model3D(let stitchEntity):
//            stitchEntity.containerEntity.transform = .init()
//        default:
//            return
//        }
    }
}

extension MediaViewModel: StitchEngine.MediaEphemeralObservable {
    typealias Node = NodeViewModel
    
    @MainActor
    func updateInputMedia(_ media: GraphMediaValue?) {
        self.inputMedia = media
    }
}

extension MediaEvalOpViewable {
    @MainActor
    var inputMedia: GraphMediaValue? {
        get {
            self.mediaViewModel.inputMedia
        }
        set(newValue) {
            self.mediaViewModel.inputMedia = newValue
        }
    }
    
    @MainActor
    var computedMedia: GraphMediaValue? {
        get {
            self.mediaViewModel.computedMedia
        }
        set(newValue) {
            self.mediaViewModel.computedMedia = newValue
        }
    }
}

extension MediaEvalOpObservable {
    /// Condtionally gets or creates new media object based on input media and possible existence of current media
    /// at this loop index.
    @MainActor func getUniqueMedia(inputMediaValue: AsyncMediaValue?,
                                   inputPortIndex: Int,
                                   loopIndex: Int) async -> GraphMediaValue? {
        // Get already existing media if matching ID
        if self.inputMedia?.id == inputMediaValue?.id {
            return self.inputMedia
        }
        
        if let node = self.nodeDelegate {
            let media = await Self.getUniqueMedia(node: node,
                                                  inputMediaValue: inputMediaValue,
                                                  inputPortIndex: inputPortIndex,
                                                  loopIndex: loopIndex)
            
            // Save media to observer
            self.inputMedia = media
            
            return media
        }
        
        return nil
    }
    
    @MainActor func resetMedia() {
        self.inputMedia = nil
        self.computedMedia = nil
    }
    
    /// A specific media eval handler that only creates new media when a particular input's media value has changed.
    @MainActor func mediaEvalOpCoordinator<MediaEvalResult>(inputPortIndex: Int,
                                                            values: [MediaEvalResult.ValueType],
                                                            loopIndex: Int,
                                                            defaultOutputs: [MediaEvalResult.ValueType],
                                                            evalOp: @escaping @MainActor (GraphMediaValue) -> [MediaEvalResult.ValueType]) -> MediaEvalResult where MediaEvalResult: MediaEvalResultable {
        guard let node = self.nodeDelegate else {
            return .init(from: defaultOutputs)
        }
        
        let mediaObserver = self
        let inputMediaValue = MediaEvalResult.getInputMediaValue(from: values)
        
        // This kind of media is saved in ephemeral observers
        let currentMedia = node.getComputedMediaValue(loopIndex: loopIndex,
                                                      mediaId: nil)
                
        let didMediaChange = inputMediaValue?.id != currentMedia?.id
        let isLoadingNewMedia = mediaObserver.currentLoadingMediaId != nil
        let willLoadNewMedia = didMediaChange && !isLoadingNewMedia
        
        guard !willLoadNewMedia else {
            mediaObserver.currentLoadingMediaId = inputMediaValue?.id
            
            guard let inputMediaValue = inputMediaValue else {
                // Set to nil case
                mediaObserver.resetMedia()
                return .init(from: defaultOutputs)
            }
            
            // Create new unique copy
            return mediaObserver
                .asyncMediaEvalOp(loopIndex: loopIndex,
                                  values: values) { [weak mediaObserver] () -> MediaEvalResult in
                guard let media = await mediaObserver?.getUniqueMedia(inputMediaValue: inputMediaValue,
                                                                      inputPortIndex: inputPortIndex,
                                                                      loopIndex: loopIndex) else {
                    return .init(from: defaultOutputs)
                }
                
                let outputs = await evalOp(media)
                
                return .init(values: outputs,
                             media: media)
            }
        }
        
        guard let currentMedia = currentMedia else {
            return .init(from: defaultOutputs)
        }

        let outputs = evalOp(currentMedia)
        return .init(values: outputs,
                     media: currentMedia)
    }

    /// Condtionally gets or creates new media object based on input media and possible existence of current media
    /// at this loop index.
    @MainActor static func getUniqueMedia(node: NodeViewModel,
                                          inputMediaValue: AsyncMediaValue?,
                                          inputPortIndex: Int,
                                          loopIndex: Int) async -> GraphMediaValue? {
        guard let inputMediaValue = inputMediaValue else {
            return nil
        }

        // Create new media for input if media key and no media set yet
        if let graphDelegate = node.graphDelegate,
           let mediaKey = inputMediaValue.dataType.mediaKey {
            // Async create media object and recalculate full node when complete
            let mediaObject = await MediaEvalOpCoordinator
                .createMediaValue(from: mediaKey,
                                  isComputedCopy: false,    // always import scenario here
                                  mediaId: inputMediaValue.id,
                                  graphDelegate: graphDelegate)
            
            return mediaObject
        }
        
        // No media key scenario
        if let mediaObject = node.getInputMedia(portIndex: inputPortIndex,
                                                loopIndex: loopIndex,
                                                mediaId: inputMediaValue.id) {
            // Create computed copy from another computed media object
            guard let copy = try? await mediaObject.createComputedCopy() else {
                fatalErrorIfDebug()

                return nil
            }
            let newMediaValue = GraphMediaValue(id: inputMediaValue.id,
                                                dataType: .computed, // copies are always computed
                                                mediaObject: copy)
            
            return newMediaValue
        }
        
        return nil
    }
    
    /// Async callback to prevent data races for media object changes.
    @MainActor func asyncMediaEvalOp<MediaEvalResult>(loopIndex: Int,
                                                      values: [MediaEvalResult.ValueType],
                                                      callback: @Sendable @escaping () async -> MediaEvalResult) -> MediaEvalResult where MediaEvalResult: MediaEvalResultable {
        self.asyncMediaEvalOp(loopIndex: loopIndex,
                              values: values,
                              node: self.nodeDelegate,
                              callback: callback)
    }
    
    /// Async callback to prevent data races for media object changes.
    @MainActor func asyncMediaEvalOp<MediaEvalResult>(loopIndex: Int,
                                                      values: [MediaEvalResult.ValueType],
                                                      node: NodeViewModel?,
                                                      callback: @Sendable @escaping () async -> MediaEvalResult) -> MediaEvalResult where MediaEvalResult: MediaEvalResultable {
        guard let nodeDelegate = node else {
            fatalErrorIfDebug()
            return .init(from: [])
        }

        let outputs = MediaEvalResult(from: values).prevOutputs(node: nodeDelegate)
        let currentMedia = self.computedMedia
        
        Task(priority: .high) { [weak self, weak nodeDelegate] in
            guard let nodeDelegate = nodeDelegate else {
                return
            }
            await self?.mediaActor.asyncMediaEvalOp(loopIndex: loopIndex,
                                                    node: nodeDelegate,
                                                    callback: callback)
        }
        
        return .init(values: outputs,
                     media: currentMedia)
    }

    /// Async callback to prevent data races for media object changes.
    @MainActor func asyncMediaEvalOp(loopIndex: Int,
                                     values: PortValues,
                                     node: NodeViewModel?,
                                     callback: @Sendable @escaping () async -> PortValues) -> PortValues {
        guard let nodeDelegate = node else {
            fatalErrorIfDebug()
            return []
        }

        let outputs = values.prevOutputs(node: nodeDelegate)
        
        Task(priority: .high) { [weak self, weak nodeDelegate] in
            guard let nodeDelegate = nodeDelegate else {
                return
            }
            await self?.mediaActor.asyncMediaEvalOp(loopIndex: loopIndex,
                                                    node: nodeDelegate,
                                                    callback: callback)
        }
        
        return outputs
    }
    
    /// Async callback to prevent data races for media object changes.
    @MainActor func asyncMediaEvalOpList(node: NodeViewModel?,
                                         callback: @Sendable @escaping () async -> PortValuesList) -> PortValuesList {
        guard let nodeDelegate = node else {
            fatalErrorIfDebug()
            return []
        }

        let prevOutputs = nodeDelegate.outputs
        
        Task(priority: .high) { [weak self, weak nodeDelegate] in
            guard let nodeDelegate = nodeDelegate else {
                return
            }
            await self?.mediaActor.asyncMediaEvalOpList(node: nodeDelegate,
                                                        callback: callback)
        }
        
        return prevOutputs
    }
}

extension PortValues {
    /// Gets outputs from  a list of inputs + outputs, defaulting to default outputs if no outputs passed in list.
    @MainActor
    func prevOutputs(node: NodeViewModel) -> PortValues {
        self.prevOutputs(nodeKind: node.kind) ?? node.defaultOutputs
    }
    
    /// Gets outputs from  a list of inputs + outputs.
    @MainActor
    func prevOutputs(nodeKind: NodeKind) -> PortValues? {
        // Just get inputs count, user visible type doesn't matter
        let inputsCount = nodeKind.rowDefinitions(for: nil).inputs.count
        
        let firstOutputIndex = inputsCount
        guard self.count > firstOutputIndex else {
            return nil
        }
        return Array(self.dropFirst(inputsCount))
    }
}

actor MediaEvalOpCoordinator {
    @MainActor
    static func createMediaValue(from mediaKey: MediaKey,
                                 isComputedCopy: Bool, // true if intended for node's output
                                 mediaId: UUID,
                                 graphDelegate: GraphState) async -> GraphMediaValue? {
        guard let url = graphDelegate.getMediaUrl(forKey: mediaKey) else {
            return nil
        }
        
        let mediaResultFromFile = await graphDelegate
            .createMediaObject(mediaKey: mediaKey,
                               url: url)
        
        switch mediaResultFromFile {
        case .success(let mediaObjectFromFile):
            guard let mediaObjectFromFile = mediaObjectFromFile else {
                return nil
            }
            
            if isComputedCopy {
                return GraphMediaValue(id: mediaId,
                                       dataType: .computed,
                                       mediaObject: mediaObjectFromFile)
            } else {
                return GraphMediaValue(id: mediaId,
                                       dataType: .source(mediaKey),
                                       mediaObject: mediaObjectFromFile)
            }
        case .failure(let error):
            dispatch(DisplayError(error: error))
            
            return nil
        }
    }
    
    /// Async callback to prevent data races for media object changes.
    func asyncMediaEvalOp(loopIndex: Int,
                          node: NodeViewModel,
                          callback: @Sendable @escaping () async -> PortValues) async {
        let newOutputs = await callback()
        await node.graphDelegate?
            .recalculateGraphForMedia(outputValues: .byIndex(newOutputs),
                                      media: nil,
                                      nodeId: node.id,
                                      loopIndex: loopIndex)
    }
    
    /// Async callback to prevent data races for media object changes.
    func asyncMediaEvalOp<MediaEvalResult>(loopIndex: Int,
                                           node: NodeViewModel,
                                           callback: @Sendable @escaping () async -> MediaEvalResult) async where MediaEvalResult: MediaEvalResultable {
        let result = await callback()
        await node.graphDelegate?.recalculateGraphForMedia(result: result,
                                                           nodeId: node.id,
                                                           loopIndex: loopIndex)
    }
    
    /// Async callback to prevent data races for media object changes.
    func asyncMediaEvalOpList(node: NodeViewModel,
                              callback: @Sendable @escaping () async -> PortValuesList) async {
        let newOutputs = await callback()
        await node.graphDelegate?
            .recalculateGraphForMedia(outputValues: .all(newOutputs),
                                      media: nil,
                                      nodeId: node.id,
                                      loopIndex: 0)
    }
}
