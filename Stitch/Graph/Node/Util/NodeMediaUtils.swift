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

protocol MediaEvalResultable: Sendable {
    associatedtype ValueType: Sendable
    
    var media: GraphMediaValue? { get set }
    
    var valueResult: AsyncMediaOutputs { get }
    
    @MainActor
    func prevOutputs(node: NodeViewModel) -> [ValueType]
    
    static func getInputMediaValue(from inputs: [ValueType]) -> AsyncMediaValue?
    
    init(from values: [ValueType])
    
    init(values: [ValueType],
         media: GraphMediaValue?)
}

struct MediaEvalOpResult: MediaEvalResultable {
    var values: PortValues
    var media: GraphMediaValue?
}

extension MediaEvalOpResult: NodeEvalOpResult {
    var valueResult: AsyncMediaOutputs { .byIndex(self.values) }
    
    @MainActor
    func prevOutputs(node: NodeViewModel) -> PortValues {
        self.values.prevOutputs(node: node)
    }
    
    static func getInputMediaValue(from inputs: PortValues) -> AsyncMediaValue? {
        inputs.first?.asyncMedia
    }
    
    static func createEvalResult(from results: [MediaEvalOpResult],
                                 node: NodeViewModel) -> EvalResult {
        let valuesList = results.map { $0.values }
        let mediaList = results.map { $0.media }
        
        // Values need to be re-mapped by port index since self
        // is an array of results for each loop index.
        let outputs = valuesList.remapOutputs()
        
        // Update ephemeral observers
        for (newMedia, ephemeralObserver) in zip(mediaList, node.ephemeralObservers ?? []) {
            guard let mediaObserver = ephemeralObserver as? MediaEvalOpViewable else {
                fatalErrorIfDebug()
                break
            }
            
            if let newMedia = newMedia {
                mediaObserver.currentMedia = newMedia
            } else {
                mediaObserver.currentMedia = nil
            }
        }
        
        return .init(outputsValues: outputs)
    }
    
    init(from values: PortValues) {
        self.values = values
        self.media = nil
    }
}

/// Used by Core ML Detection node.
struct MediaEvalValuesListResult: NodeEvalOpResult, MediaEvalResultable {
    var valuesList: PortValuesList
    var media: GraphMediaValue?
}

extension MediaEvalValuesListResult {
    init(from values: PortValuesList) {
        self.valuesList = values
    }
    
    init(from values: PortValues) {
        self.valuesList = [values]
    }
    
    init(values: PortValuesList,
         media: GraphMediaValue?) {
        self.valuesList = values
        self.media = media
    }
    
    var valueResult: AsyncMediaOutputs { .all(self.valuesList) }
    
    static func getInputMediaValue(from inputs: PortValuesList) -> AsyncMediaValue? {
        inputs.first?.first?.asyncMedia
    }
    
    @MainActor
    func prevOutputs(node: NodeViewModel) -> PortValuesList {
        node.outputs
    }
    
    @MainActor
    static func createEvalResult(from results: [MediaEvalValuesListResult],
                                 node: NodeViewModel) -> EvalResult {
        guard let result = results.first,
              results.count == 1 else {
            fatalErrorIfDebug()
            return .init()
        }
        
        let outputs = result.valuesList
        let media = result.media
        
        // Update ephemeral observer
        guard let mediaObserver = node.ephemeralObservers?.first as? MediaEvalOpViewable else {
            fatalErrorIfDebug()
            return .init()
        }
        
        if let newMedia = media {
            mediaObserver.currentMedia = newMedia
        } else {
            mediaObserver.currentMedia = nil
        }
        
        return .init(outputsValues: outputs)
    }
}

extension NodeViewModel {
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(coordinate: NodeIOCoordinate,
                       loopIndex: Int,
                       mediaId: UUID) -> StitchMediaObject? {
        self.getInputMediaObserver(inputCoordinate: coordinate,
                                   loopIndex: loopIndex,
                                   mediaId: mediaId)?.currentMedia?.mediaObject
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(portIndex: Int,
                       loopIndex: Int,
                       mediaId: UUID?) -> StitchMediaObject? {
        self.getInputMediaValue(portIndex: portIndex,
                                loopIndex: loopIndex,
                                mediaId: mediaId)?.mediaObject
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaValue(portIndex: Int,
                            loopIndex: Int,
                            mediaId: UUID?) -> GraphMediaValue? {
        self.getInputMediaObserver(portIndex: portIndex,
                                   loopIndex: loopIndex,
                                   mediaId: mediaId)?.currentMedia
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaValue(coordinate: NodeIOCoordinate,
                            loopIndex: Int,
                            mediaId: UUID) -> GraphMediaValue? {
        self.getInputMediaObserver(inputCoordinate: coordinate,
                                   loopIndex: loopIndex,
                                   mediaId: mediaId)?.currentMedia
    }

    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMediaValue(loopIndex: Int,
                               mediaId: UUID?) -> GraphMediaValue? {
        self.getComputedMediaObserver(loopIndex: loopIndex,
                                      mediaId: mediaId)?.currentMedia
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMedia(loopIndex: Int,
                          mediaId: UUID) -> StitchMediaObject? {
        self.getComputedMediaValue(loopIndex: loopIndex,
                                   mediaId: mediaId)?.mediaObject
    }
    
    /// Used for fields.
    @MainActor
    func getVisibleMediaObserver(inputCoordinate: NodeIOCoordinate,
                                 mediaId: UUID,
                                 graph: GraphState,
                                 activeIndex: ActiveIndex) -> MediaViewModel? {
        guard let rowObserver = self.getInputRowObserver(for: inputCoordinate.portType) else {
            fatalErrorIfDebug()
            return nil
        }
        
        let loopIndex = rowObserver.getActiveLoopIndex(graph: graph,
                                                       activeIndex: activeIndex)
        return self.getInputMediaObserver(inputCoordinate: inputCoordinate,
                                          loopIndex: loopIndex,
                                          mediaId: mediaId)
    }
    
    /// Used for fields.
    @MainActor
    func getVisibleMediaObserver(outputPortId: Int,
                                 mediaId: UUID?,
                                 graph: GraphState,
                                 activeIndex: ActiveIndex) -> MediaViewModel? {
        guard let rowObserver = self.getOutputRowObserver(for: outputPortId) else {
            fatalErrorIfDebug()
            return nil
        }
        
        let loopIndex = rowObserver.getActiveLoopIndex(graph: graph,
                                                       activeIndex: activeIndex)
        return self.getComputedMediaObserver(loopIndex: loopIndex,
                                             mediaId: mediaId)
    }
    
    @MainActor
    func getInputMediaObserver(inputCoordinate: NodeIOCoordinate,
                               loopIndex: Int,
                               mediaId: UUID?) -> MediaViewModel? {
        switch inputCoordinate.portType {
        case .portIndex(let portIndex):
            return self.getInputMediaObserver(portIndex: portIndex,
                                              loopIndex: loopIndex,
                                              mediaId: mediaId)
            
        case .keyPath(let keyPath):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            // MARK: helpers here will not retrieve local imported layer view model, thorough testing needed if scope increases
            return layerNode.getConnectedInputMediaObserver(keyPath: keyPath,
                                                            loopIndex: loopIndex,
                                                            mediaId: mediaId)
        }
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaObserver(portIndex: Int,
                               loopIndex: Int,
                               mediaId: UUID?) -> MediaViewModel? {
        // Do nothing if no upstream connection for media
        guard let connectedUpstreamNode = self.getUpstreamNode(inputPortIndex: portIndex) else {
            
            // MARK: below functionality allows nodes like media import patch nodes to display media at the input even though computed ephemeral observers only hold media. For some nodes like loop builder this isn't ideal as it'll incorrectly display valid data at an empty input.
            if self.kind == .patch(.loopBuilder) {
                return nil
            }
            
            // Check if media eval op exists here if no connection
            return self.getComputedMediaObserver(loopIndex: loopIndex,
                                                 mediaId: mediaId)
        }
        
        return connectedUpstreamNode.getUpstreamNodeMediaObserver(loopIndex: loopIndex,
                                                                  mediaId: mediaId)
    }
    
    @MainActor
    private func getUpstreamNode(inputPortIndex: Int) -> NodeViewModel? {
        self.inputsObservers[safe: inputPortIndex]?.upstreamOutputObserver?.nodeDelegate
    }
    
    @MainActor
    private func getUpstreamNodeMediaObserver(loopIndex: Int,
                                              mediaId: UUID?) -> MediaViewModel? {
        // Media object is obtained by looking at upstream connected node's saved media objects.
        if let viewModel = self.getComputedMediaObserver(loopIndex: loopIndex,
                                                                          mediaId: mediaId) {
            return viewModel
        }
        
        // Fallback logic below: recursively check upstream nodes at the firt port index. Provides support for nodes like splitters which don't directly hold media.
        return self.getInputMediaObserver(portIndex: 0,
                                          loopIndex: loopIndex,
                                          mediaId: mediaId)
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMediaObserver(loopIndex: Int,
                                  mediaId: UUID?) -> MediaViewModel? {
        // Check if media eval op exists here if no connection
        if let viewModel = (self.ephemeralObservers?[safe: loopIndex] as? MediaEvalOpViewable)?.mediaViewModel {
            // Only check on media ID if provided, else always return object
            if let mediaId = mediaId,
               viewModel.currentMedia?.id == mediaId {
                return viewModel
            }
            
            return viewModel
        }
        
        return nil
    }
}

extension NodeRowObserver {
    @MainActor
    func getActiveLoopIndex(graph: GraphState,
                            activeIndex: ActiveIndex) -> Int {
        activeIndex.adjustedIndex(self.allLoopedValues.count)
    }
}

extension LayerNodeViewModel {
    @MainActor
    func getConnectedInputMedia(keyPath: LayerInputType,
                                loopIndex: Int,
                                mediaId: UUID) -> StitchMediaObject? {
        if let mediaValue = self.getConnectedInputMediaObserver(keyPath: keyPath,
                                                                loopIndex: loopIndex,
                                                                mediaId: mediaId)?.currentMedia {
            return mediaValue.mediaObject
        }
        
        return nil
    }
    
    @MainActor
    /// Gets the media observer for some connected input.
    func getConnectedInputMediaObserver(keyPath: LayerInputType,
                                        loopIndex: Int,
                                        mediaId: UUID?) -> MediaViewModel? {
        let port = self[keyPath: keyPath.layerNodeKeyPath]
        
        if let upstreamObserver = port.rowObserver.upstreamOutputObserver,
           let upstreamNode = upstreamObserver.nodeDelegate {
            if let upstreamComputedMedia = upstreamNode
                .getComputedMediaObserver(loopIndex: loopIndex,
                                          mediaId: mediaId) {
                return upstreamComputedMedia
            }
            
            // Fallback logic: check input of upstream node and kick-start recursive strategy
            return upstreamNode.getInputMediaObserver(portIndex: 0,
                                                      loopIndex: loopIndex,
                                                      mediaId: mediaId)
        }
        
        // No upstream connection, find media at layer view model
        guard let layerViewModel = self.previewLayerViewModels[safe: loopIndex],
              layerViewModel.mediaViewModel.currentMedia?.id == mediaId else {
            return nil
        }

        return layerViewModel.mediaViewModel
    }
}
