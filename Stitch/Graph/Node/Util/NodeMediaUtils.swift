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
    @MainActor var inputMedia: GraphMediaValue?
    
    @MainActor var computedMedia: GraphMediaValue?
    
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

extension MediaEvalOpResult: NodeEvalOpResultable {
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
        
        return .init(outputsValues: outputs,
                     mediaList: mediaList)
    }
    
    init(from values: PortValues) {
        self.values = values
        self.media = nil
    }
}

/// Used by Core ML Detection node.
struct MediaEvalValuesListResult: NodeEvalOpResultable, MediaEvalResultable {
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
            mediaObserver.computedMedia = newMedia
        } else {
            mediaObserver.computedMedia = nil
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
        self.getMediaObserver(portType: coordinate.portType,
                              loopIndex: loopIndex,
                              mediaId: mediaId)?.inputMedia?.mediaObject
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
        self.getMediaObserver(portType: .portIndex(portIndex),
                              loopIndex: loopIndex,
                              mediaId: mediaId)?.inputMedia
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMediaValue(coordinate: NodeIOCoordinate,
                            loopIndex: Int,
                            mediaId: UUID) -> GraphMediaValue? {
        self.getMediaObserver(portType: coordinate.portType,
                              loopIndex: loopIndex,
                              mediaId: mediaId)?.inputMedia
    }

    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMediaValue(loopIndex: Int,
                               mediaId: UUID?) -> GraphMediaValue? {
        self.getMediaObserver(loopIndex: loopIndex,
                              mediaId: mediaId)?.computedMedia
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMedia(loopIndex: Int,
                          mediaId: UUID) -> StitchMediaObject? {
        self.getComputedMediaValue(loopIndex: loopIndex,
                                   mediaId: mediaId)?.mediaObject
    }
    
    @MainActor
    func getMediaObserver(portType: NodeIOPortType,
                          loopIndex: Int,
                          mediaId: UUID?) -> MediaViewModel? {
        switch portType {
        case .portIndex:
            return self.getMediaObserver(loopIndex: loopIndex,
                                         mediaId: mediaId)
            
        case .keyPath:
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            return layerNode.previewLayerViewModels[safe: loopIndex]?.mediaViewModel
        }
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getMediaObserver(loopIndex: Int,
                          mediaId: UUID?) -> MediaViewModel? {        
        // MARK: below functionality allows nodes like media import patch nodes to display media at the input even though computed ephemeral observers only hold media. For some nodes like loop builder this isn't ideal as it'll incorrectly display valid data at an empty input.
        if self.kind == .patch(.loopBuilder) {
            return nil
        }
        
        // Check if media eval op exists here if no connection
        if let viewModel = (self.ephemeralObservers?[safe: loopIndex] as? MediaEvalOpViewable)?.mediaViewModel {            
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
