//
//  MediaEvalOpObservable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

protocol MediaEvalOpObservable: NodeEphemeralObservable, Sendable {
    @MainActor var nodeDelegate: NodeDelegate? { get set }

    @MainActor var currentMedia: GraphMediaValue? { get set }
    
    @MainActor var currentLoadingMediaId: UUID? { get set }
    
    var mediaActor: MediaEvalOpCoordinator { get }
}

final class MediaEvalOpObserver: MediaEvalOpObservable {
    var currentMedia: GraphMediaValue?
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeDelegate?
    internal let mediaActor = MediaEvalOpCoordinator()
}

final class VisionOpObserver: MediaEvalOpObservable {
    var currentMedia: GraphMediaValue?
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeDelegate?
    internal let mediaActor = MediaEvalOpCoordinator()
    let coreMlActor = VisionOpActor()
    
    func onPrototypeRestart() { }
}

final class ImageClassifierOpObserver: MediaEvalOpObservable {
    var currentMedia: GraphMediaValue?
    var currentLoadingMediaId: UUID?
    weak var nodeDelegate: NodeDelegate?
    internal let mediaActor = MediaEvalOpCoordinator()
    let coreMlActor = ImageClassifierActor()
    
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
            stitchEntity.entityStatus.loadedInstance?.transform = .init()
        case .arAnchor(let anchorEntity):
            anchorEntity.transform = .init()
        default:
            return
        }
    }
}

extension MediaEvalOpObservable {
    /// Condtionally gets or creates new media object based on input media and possible existence of current media
    /// at this loop index.
    @MainActor func getUniqueMedia(from value: PortValue?,
                                   loopIndex: Int) -> GraphMediaValue? {
        self.getUniqueMedia(from: value?._asyncMedia,
                            loopIndex: loopIndex)
    }
    
    @MainActor func resetMedia() {
        self.currentMedia = nil
    }

    /// Condtionally gets or creates new media object based on input media and possible existence of current media
    /// at this loop index.
    @MainActor func getUniqueMedia(from inputMedia: AsyncMediaValue?,
                                   loopIndex: Int) -> GraphMediaValue? {
        guard let inputMedia = inputMedia else {
            self.currentMedia = nil
            return nil
        }
        
        // Input ID's changed and not currently loading same ID
        let needsNewComputedCopy = inputMedia.id != self.currentMedia?.portValue._asyncMedia?.id &&
        self.currentLoadingMediaId != inputMedia.id
        let mediaObject = GraphMediaValue(from: inputMedia)?.mediaObject
        let nodeId = self.nodeDelegate?.id
        
        assertInDebug(nodeId != nil)
        
        guard needsNewComputedCopy else {
            // Return same object if no expected change
            return self.currentMedia
        }
         
        // Cases below are when media has fundamentally changed
        self.currentLoadingMediaId = inputMedia.id
        self.currentMedia = nil
        
        // Create new media for input if media key and no media set yet
        if let graphDelegate = nodeDelegate?.graphDelegate,
           let mediaKey = inputMedia.dataType.mediaKey {
            // Async create media object and recalculate full node when complete
            Task(priority: .high) { [weak self, weak graphDelegate] in
                guard let graphDelegate = graphDelegate else { return }
                
                let mediaObject = await MediaEvalOpCoordinator
                    .createMediaValue(from: mediaKey,
                                      isComputedCopy: false,    // always import scenario here
                                      mediaId: inputMedia.id,
                                      graphDelegate: graphDelegate,
                                      nodeId: nodeId)
                
                await MainActor.run { [weak self] in
                    self?.updateInputMedia(mediaObject,
                                           loopIndex: loopIndex)
                }
            }
            
            return nil
        }
        
        if let mediaObject = mediaObject {
            // Create computed copy from another computed media object
            Task(priority: .high) { [weak self] in
                guard let copy = await mediaObject.createComputedCopy(nodeId: nodeId) else {
                    fatalErrorIfDebug()
                    
                    await MainActor.run { [weak self] in
                        self?.currentMedia = nil
                    }
                    return
                }
                let newMediaValue = GraphMediaValue(id: inputMedia.id,
                                                    dataType: .computed, // copies are always computed
                                                    mediaObject: copy)
                
                // Update current observer to track new value
                await MainActor.run { [weak self] in
                    self?.updateInputMedia(newMediaValue,
                                           loopIndex: loopIndex)
                }
            }
        }
        
        return nil
    }
    
    @MainActor func updateInputMedia(_ newMediaValue: GraphMediaValue?,
                                     loopIndex: Int) {
        self.currentMedia = newMediaValue
        
        self.currentLoadingMediaId = nil
        
        // Recalculate node once new media is set
        self.nodeDelegate?.calculate()
        
        // A bit of a hack to get fields to update with loaded media
        if let mediaPortRow = self.nodeDelegate?.getInputRowObserver(0) {
            guard mediaPortRow.allLoopedValues.count > loopIndex else {
                // Hit on loops with anchors, likely not a big deal
//                fatalErrorIfDebug()
                return
            }
            
            // Update row values with new struct containing media object
            let portValue = newMediaValue?.portValue ?? .asyncMedia(nil)
            mediaPortRow.allLoopedValues[loopIndex] = portValue
            mediaPortRow
                .updateValues(mediaPortRow.allLoopedValues)
        }
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
    static func createMediaValue(from mediaKey: MediaKey,
                                 isComputedCopy: Bool, // true if intended for node's output
                                 mediaId: UUID,
                                 graphDelegate: GraphDelegate,
                                 nodeId: NodeId? = nil) async -> GraphMediaValue? {
        guard let url = await graphDelegate.getMediaUrl(forKey: mediaKey) else {
            return nil
        }
        
        let mediaResultFromFile = await graphDelegate
            .createMediaObject(mediaKey: mediaKey,
                               nodeId: nodeId,
                               url: url)
        
        switch mediaResultFromFile {
        case .success(let mediaObjectFromFile):
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
            await MainActor.run {
                dispatch(DisplayError(error: error))
            }
            
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
    func asyncMediaEvalOpList(node: NodeDelegate,
                              callback: @Sendable @escaping () async -> PortValuesList) async {
        let newOutputs = await callback()
        await node.graphDelegate?.recalculateGraph(outputValues: .all(newOutputs),
                                                   nodeId: node.id,
                                                   loopIndex: 0)
    }
}
