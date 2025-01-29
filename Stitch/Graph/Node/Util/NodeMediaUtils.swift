//
//  NodeMediaUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/28/25.
//


import SwiftUI
import StitchSchemaKit

@Observable
final class MediaViewModel: Sendable {
    @MainActor var currentMedia: GraphMediaValue?
    
    @MainActor init() { }
}

extension NodeViewModel {
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(coordinate: NodeIOCoordinate,
                       loopIndex: Int) -> StitchMediaObject? {
        self.getInputMediaObserver(inputCoordinate: coordinate,
                                   loopIndex: loopIndex)?.currentMedia?.mediaObject
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(portIndex: Int,
                       loopIndex: Int) -> StitchMediaObject? {
        self.getInputMediaObserver(portIndex: portIndex,
                                   loopIndex: loopIndex)?.currentMedia?.mediaObject
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMedia(loopIndex: Int) -> StitchMediaObject? {
        self.getComputedMediaObserver(loopIndex: loopIndex)?.currentMedia?.mediaObject
    }
    
    /// Used for fields.
    @MainActor
    func getVisibleMediaObserver(inputCoordinate: NodeIOCoordinate) -> MediaViewModel? {
        guard let rowObserver = self.getInputRowObserver(for: inputCoordinate.portType) else {
            fatalErrorIfDebug()
            return nil
        }
        
        let loopIndex = rowObserver.getActiveLoopIndex()
        return self.getInputMediaObserver(inputCoordinate: inputCoordinate,
                                          loopIndex: loopIndex)
    }
    
    /// Used for fields.
    @MainActor
    func getVisibleMediaObserver(outputPortId: Int) -> MediaViewModel? {
        guard let rowObserver = self.getOutputRowObserver(outputPortId) else {
            fatalErrorIfDebug()
            return nil
        }
        
        let loopIndex = rowObserver.getActiveLoopIndex()
        return self.getComputedMediaObserver(loopIndex: loopIndex)
    }
    
    @MainActor
    func getInputMediaObserver(inputCoordinate: NodeIOCoordinate,
                               loopIndex: Int) -> MediaViewModel? {
        switch inputCoordinate.portType {
        case .portIndex(let portIndex):
            return self.getInputMediaObserver(portIndex: portIndex,
                                      loopIndex: loopIndex)
            
        case .keyPath(let keyPath):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            // MARK: helpers here will not retrieve local imported layer view model, thorough testing needed if scope increases
            return layerNode.getConnectedInputMediaObserver(keyPath: keyPath,
                                                            loopIndex: loopIndex)
        }
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaObserver(portIndex: Int,
                               loopIndex: Int) -> MediaViewModel? {
        // Do nothing if no upstream connection for media
        guard let connectedUpstreamObserver = self.inputsObservers[safe: portIndex]?.upstreamOutputObserver,
                let connectedUpstreamNode = connectedUpstreamObserver.nodeDelegate else {
            // Check if media eval op exists here if no connection
            return self.getComputedMediaObserver(loopIndex: loopIndex)
        }
        
        // MARK: media object is obtained by looking at upstream connected node's saved media objects. This system isn't perfect as not all nodes which can hold media use the MediaEvalOpObservable.
        return connectedUpstreamNode.getComputedMediaObserver(loopIndex: loopIndex)
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMediaObserver(loopIndex: Int) -> MediaViewModel? {
        // Check if media eval op exists here if no connection
        (self.ephemeralObservers?[safe: loopIndex] as? MediaEvalOpObservable)?.mediaViewModel
    }
}

extension NodeRowObserver {
    @MainActor
    func getActiveLoopIndex() -> Int {
        self.nodeDelegate?.graphDelegate?.activeIndex.adjustedIndex(self.allLoopedValues.count) ?? .zero
    }
}

extension LayerNodeViewModel {
    @MainActor
    func getConnectedInputMedia(keyPath: LayerInputType,
                                loopIndex: Int) -> StitchMediaObject? {
        self.getConnectedInputMediaObserver(keyPath: keyPath,
                                            loopIndex: loopIndex)?
            .currentMedia?.mediaObject
    }
    
    @MainActor
    /// Gets the media observer for some connected input.
    func getConnectedInputMediaObserver(keyPath: LayerInputType,
                                        loopIndex: Int) -> MediaViewModel? {
        let port = self[keyPath: keyPath.layerNodeKeyPath]
        
        if let upstreamObserver = port.rowObserver.upstreamOutputObserver,
           let upstreamNode = upstreamObserver.nodeDelegate {
            return upstreamNode.getComputedMediaObserver(loopIndex: loopIndex)
        }
        
//        // No upstream connection, find media at layer view model
//        guard let layerViewModel = self.previewLayerViewModels[safe: loopIndex] else {
//            return nil
//        }
//
//        return layerViewModel.mediaObject
        
        return nil
    }
}
