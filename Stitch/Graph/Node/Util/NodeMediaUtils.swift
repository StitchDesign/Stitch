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
                       loopIndex: Int) -> StitchMediaObject? {
        self.getInputMediaObserver(inputCoordinate: coordinate,
                                   loopIndex: loopIndex)?.currentMedia?.mediaObject
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(portIndex: Int,
                       loopIndex: Int) -> StitchMediaObject? {
        self.getInputMediaValue(portIndex: portIndex,
                                loopIndex: loopIndex)?.mediaObject
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaValue(portIndex: Int,
                            loopIndex: Int) -> GraphMediaValue? {
        self.getInputMediaObserver(portIndex: portIndex,
                                   loopIndex: loopIndex)?.currentMedia
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaValue(coordinate: NodeIOCoordinate,
                            loopIndex: Int) -> GraphMediaValue? {
        self.getInputMediaObserver(inputCoordinate: coordinate,
                                   loopIndex: loopIndex)?.currentMedia
    }

    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMediaValue(loopIndex: Int) -> GraphMediaValue? {
        self.getComputedMediaObserver(loopIndex: loopIndex)?.currentMedia
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMedia(loopIndex: Int) -> StitchMediaObject? {
        self.getComputedMediaValue(loopIndex: loopIndex)?.mediaObject
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
            // MARK: below functionality allows nodes like media import patch nodes to display media at the input even though computed ephemeral observers only hold media. For some nodes like loop builder this isn't ideal as it'll incorrectly display valid data at an empty input.
            if self.kind == .patch(.loopBuilder) {
                return nil
            }
            
            // Check if media eval op exists here if no connection
            return self.getComputedMediaObserver(loopIndex: loopIndex)
        }
        
        // Media object is obtained by looking at upstream connected node's saved media objects.
        return connectedUpstreamNode.getComputedMediaObserver(loopIndex: loopIndex)
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMediaObserver(loopIndex: Int) -> MediaViewModel? {
        // Check if media eval op exists here if no connection
        (self.ephemeralObservers?[safe: loopIndex] as? MediaEvalOpViewable)?.mediaViewModel
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
        
        // No upstream connection, find media at layer view model
        guard let layerViewModel = self.previewLayerViewModels[safe: loopIndex] else {
            return nil
        }

        return layerViewModel.mediaViewModel
    }
}
