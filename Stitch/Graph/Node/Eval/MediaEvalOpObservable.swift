//
//  MediaEvalOpObservable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

/// Creates observable class with presentable media.
protocol MediaEvalOpViewable: NodeEphemeralObservable, Sendable {
    var mediaViewModel: MediaViewModel { get }
}

protocol MediaEvalOpObservable: NodeEphemeralObservable, MediaEvalOpViewable, Sendable {
    @MainActor var nodeDelegate: NodeDelegate? { get set }
    
    @MainActor var currentLoadingMediaId: UUID? { get set }
    
    var mediaActor: MediaEvalOpCoordinator { get }
}

final class MediaEvalOpObserver: MediaEvalOpObservable {
    let mediaViewModel: MediaViewModel
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeDelegate?
    internal let mediaActor = MediaEvalOpCoordinator()
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
}

final class VisionOpObserver: MediaEvalOpObservable {
    let mediaViewModel: MediaViewModel
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeDelegate?
    internal let mediaActor = MediaEvalOpCoordinator()
    let coreMlActor = VisionOpActor()
        
    @MainActor init() {
        self.mediaViewModel = .init()
    }

    func onPrototypeRestart() { }
}

final class ImageClassifierOpObserver: MediaEvalOpObservable {
    let mediaViewModel: MediaViewModel
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeDelegate?
    internal let mediaActor = MediaEvalOpCoordinator()
    let coreMlActor = ImageClassifierActor()
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
    
    func onPrototypeRestart() { }
}

extension MediaEvalOpObserver {
    @MainActor func onPrototypeRestart() {
        switch currentMedia?.mediaObject {
        case .video(let videoPlayer):
            videoPlayer.resetPlayer()
        case .soundfile(let soundPlayer):
            soundPlayer.delegate.setJumpTime(.zero)
        case .model3D(let stitchEntity):
            stitchEntity.containerEntity.transform = .init()
        default:
            return
        }
    }
}

extension MediaEvalOpViewable {
    @MainActor
    var currentMedia: GraphMediaValue? {
        get {
            self.mediaViewModel.currentMedia
        }
        set(newValue) {
            self.mediaViewModel.currentMedia = newValue
        }
    }
}

extension MediaEvalOpObservable {
    /// Condtionally gets or creates new media object based on input media and possible existence of current media
    /// at this loop index.
    @MainActor func getUniqueMedia(inputMediaValue: AsyncMediaValue?,
                                   inputPortIndex: Int,
                                   loopIndex: Int) async -> GraphMediaValue? {
        if let node = self.nodeDelegate {
            return await Self.getUniqueMedia(node: node,
                                             inputMediaValue: inputMediaValue,
                                             inputPortIndex: inputPortIndex,
                                             loopIndex: loopIndex)
        }
        
        return nil
    }
    
    @MainActor func resetMedia() {
        self.currentMedia = nil
    }
    
    /// A specific media eval handler that only creates new media when a particular input's media value has changed.
    @MainActor func mediaEvalOpCoordinator(inputPortIndex: Int,
                                           values: PortValues,
                                           loopIndex: Int,
                                           defaultOutputs: PortValues,
                                           evalOp: @escaping @MainActor (GraphMediaValue) -> PortValues) -> MediaEvalOpResult {
        guard let node = self.nodeDelegate else {
            return .init(from: defaultOutputs)
        }
        
        let mediaObserver = self
        let inputMediaValue = values.first?.asyncMedia
        
        // This kind of media is saved in ephemeral observers
        let currentMedia = node.getComputedMediaValue(loopIndex: loopIndex)
                
        let didMediaChange = inputMediaValue?.id != currentMedia?.id
        let isLoadingNewMedia = mediaObserver.currentLoadingMediaId != nil
        let willLoadNewMedia = didMediaChange && !isLoadingNewMedia
        
        guard !willLoadNewMedia else {
            mediaObserver.currentLoadingMediaId = inputMediaValue?.id
            
            // Create new unique copy
            return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                                  values: values,
                                                  node: node) { [weak mediaObserver] () -> MediaEvalOpResult in
                guard let media = await mediaObserver?.getUniqueMedia(inputMediaValue: inputMediaValue,
                                                                      inputPortIndex: inputPortIndex,
                                                                      loopIndex: loopIndex) else {
                    return MediaEvalOpResult(from: defaultOutputs)
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
        return MediaEvalOpResult(values: outputs,
                                 media: currentMedia)
    }

    /// Condtionally gets or creates new media object based on input media and possible existence of current media
    /// at this loop index.
    @MainActor static func getUniqueMedia(node: NodeViewModel,
                                          inputMediaValue: AsyncMediaValue?,
                                          inputPortIndex: Int,
                                          loopIndex: Int) async -> GraphMediaValue? {
        // TODO: consider removing arguments, properties etc
        
        guard let inputMediaValue = inputMediaValue else {
//            self.currentMedia = nil
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
                                                loopIndex: loopIndex) {
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
    @MainActor func asyncMediaEvalOp(loopIndex: Int,
                                     values: PortValues,
                                     node: NodeDelegate?,
                                     callback: @Sendable @escaping () async -> MediaEvalOpResult) -> MediaEvalOpResult {
        guard let nodeDelegate = node else {
            fatalErrorIfDebug()
            return .init(from: [])
        }

        let outputs = values.prevOutputs(node: nodeDelegate)
        let currentMedia = self.currentMedia
        
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
                                     node: NodeDelegate?,
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
    @MainActor func asyncMediaEvalOpList(node: NodeDelegate?,
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
    func prevOutputs(node: NodeDelegate) -> PortValues {
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
                                 graphDelegate: GraphDelegate) async -> GraphMediaValue? {
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
                          node: NodeDelegate,
                          callback: @Sendable @escaping () async -> PortValues) async {
        let newOutputs = await callback()
        await node.graphDelegate?.recalculateGraph(outputValues: .byIndex(newOutputs),
                                                   nodeId: node.id,
                                                   loopIndex: loopIndex)
    }
    
    /// Async callback to prevent data races for media object changes.
    func asyncMediaEvalOp(loopIndex: Int,
                          node: NodeDelegate,
                          callback: @Sendable @escaping () async -> MediaEvalOpResult) async {
        let result = await callback()
        await node.graphDelegate?.recalculateGraph(result: result,
                                                   nodeId: node.id,
                                                   loopIndex: loopIndex)
    }
    
    /// Async callback to prevent data races for media object changes.
    func asyncMediaEvalOpList(node: NodeDelegate,
                              callback: @Sendable @escaping () async -> PortValuesList) async {
        let newOutputs = await callback()
        await node.graphDelegate?.recalculateGraph(outputValues: .all(newOutputs),
                                                   nodeId: node.id,
                                                   loopIndex: 0)
    }
}
