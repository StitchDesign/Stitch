//
//  CanvasItemViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension CanvasItemId {
    var nodeCase: NodeId? {
        switch self {
        case .node(let nodeId):
            return nodeId
        default:
            return nil
        }
    }
    
    var layerInputCase: LayerInputCoordinate? {
        switch self {
        case .layerInput(let layerInputOnGraphId):
            return layerInputOnGraphId
        default:
            return nil
        }
    }
    
    var layerOutputCase: LayerOutputCoordinate? {
        switch self {
        case .layerOutput(let layerOutputOnGraphId):
            return layerOutputOnGraphId
        default:
            return nil
        }
    }
    
    var nodeId: NodeId {
        switch self {
        case .node(let id):
            return id
        case .layerInput(let input):
            return input.node
        case .layerOutput(let output):
            return output.node
        }
    }
}

extension CanvasItemId: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

/// Canvas can only contain at most 1 LayerInputOnGraph per a given layer node's unique port.
extension LayerInputCoordinate {
    var asInputCoordinate: InputCoordinate {
        .init(portType: .keyPath(keyPath),
              nodeId: node)
    }
}

typealias CanvasItemViewModels = [CanvasItemViewModel]

@Observable
final class CanvasItemViewModel: Identifiable, StitchLayoutCachable, Sendable {
    let id: CanvasItemId
    @MainActor var position: CGPoint = .zero
    @MainActor var previousPosition: CGPoint = .zero
    @MainActor var zIndex: Double = .zero
    @MainActor var parentGroupNodeId: NodeId?
    
    // Is this canvas item "loading"?
    // Can have multiple meanings
    @MainActor var isLoading: Bool = false
    
    @MainActor
    func isVisibleInFrame(_ visibleCanvasIds: CanvasItemIdSet) -> Bool {
        return visibleCanvasIds.contains(self.id)
    }
    
    // View specific port value data
    @MainActor var inputViewModels: [InputNodeRowViewModel] = []
    
    @MainActor var outputViewModels: [OutputNodeRowViewModel] = []
    
    // Cached subview sizes for performance gains in commit phase
    @MainActor var viewCache: NodeLayoutCache?
        
    // Reference back to the parent node entity
    @MainActor
    weak var nodeDelegate: NodeViewModel?
    
    @MainActor
    init(id: CanvasItemId,
         position: CGPoint,
         zIndex: Double,
         parentGroupNodeId: NodeId?,
         inputRowObservers: [InputNodeRowObserver],
         outputRowObservers: [OutputNodeRowObserver],
         nodeDelegate: NodeViewModel? = nil) {
        self.id = id
        self.position = position
        self.previousPosition = position
        self.zIndex = zIndex
        self.parentGroupNodeId = parentGroupNodeId
        self.nodeDelegate = nodeDelegate
        
        // Instantiate input and output row view models
        self.syncRowViewModels(inputRowObservers: inputRowObservers,
                               outputRowObservers: outputRowObservers,
                               // Assume .zero when initially creating the row view model value?
                               activeIndex: .defaultActiveIndex)
    }
}

extension CanvasItemViewModel {
    
    @MainActor
    func syncRowViewModels(inputRowObservers: [InputNodeRowObserver],
                           outputRowObservers: [OutputNodeRowObserver],
                           activeIndex: ActiveIndex) {
        
        self.syncRowViewModels(with: inputRowObservers,
                               keyPath: \.inputViewModels,
                               activeIndex: activeIndex)
        
        self.syncRowViewModels(with: outputRowObservers,
                               keyPath: \.outputViewModels,
                               activeIndex: activeIndex)
    }
    
    @MainActor
    convenience init(from canvasEntity: CanvasNodeEntity,
                     id: CanvasItemId,
                     inputRowObservers: [InputNodeRowObserver],
                     outputRowObservers: [OutputNodeRowObserver]) {
        self.init(id: id,
                  position: canvasEntity.position,
                  zIndex: canvasEntity.zIndex,
                  parentGroupNodeId: canvasEntity.parentGroupNodeId,
                  inputRowObservers: inputRowObservers,
                  outputRowObservers: outputRowObservers)
    }
    
    @MainActor
    func createSchema() -> CanvasNodeEntity {
        .init(position: self.position,
              zIndex: self.zIndex,
              parentGroupNodeId:self.parentGroupNodeId)
    }

    @MainActor
    func update(from schema: CanvasNodeEntity) {
        if self.position != schema.position {
            self.position = schema.position
        }
        
        if self.previousPosition != schema.position {
            self.previousPosition = schema.position
        }
        
        if self.zIndex != schema.zIndex {
            self.zIndex = schema.zIndex
        }
        
        if self.parentGroupNodeId != schema.parentGroupNodeId {
            self.parentGroupNodeId = schema.parentGroupNodeId
        }
        
        // Hack to fix issues where undo/redo sometimes doesn't refresh edges.
        // Not perfect as it leads to a bit of a stutter when it works.
        self.updateAnchorPoints()
    }
    
    /// Updates location of anchor points.
    // fka `updatePortLocations`
    // Note: only a canvas item's row view models can have anchor points, so it's better to define this update function on the canvas item rather than the row view model per se
    @MainActor
    func updateAnchorPoints() {
        
        guard let canvasSize = self.sizeByLocalBounds else {
            // Nothing to do if no size for canvas item yet
            return
        }
        
        let fn = { (nodeIO: NodeIO, portId: Int) -> CGPoint in
            getNewAnchorPoint(canvasPosition: self.position,
                              canvasSize: canvasSize,
                              hasLargeCanvasTitle: self.nodeDelegate?.hasLargeCanvasTitleSpace ?? false,
                              nodeIO: nodeIO,
                              portId: portId)
        }
        
        self.inputPortUIViewModels.forEach {
            let newAnchorPoint = fn(.input, $0.portIdForAnchorPoint)
            
            if newAnchorPoint != $0.anchorPoint {
                $0.anchorPoint = newAnchorPoint
            }
        }
        
        self.outputPortUIViewModels.forEach {
            let newAnchorPoint = fn(.output, $0.portIdForAnchorPoint)
            if newAnchorPoint != $0.anchorPoint {
                $0.anchorPoint = newAnchorPoint
            }
        }
    }
    
    func onPrototypeRestart(document: StitchDocumentViewModel) { }
    
    // `fka `initializeDelegate`
    @MainActor
    func assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
        _ node: NodeViewModel,
        activeIndex: ActiveIndex,
        unpackedPortParentFieldGroupType: FieldGroupType?,
        unpackedPortIndex: Int?,
        graph: GraphReader
    ) {
        
        self.assignReference(node: node)
        
        self.inputViewModels.forEach {
            if let rowObserver = graph.getInputRowObserver($0.id.asNodeIOCoordinate) {
                $0.updateFieldGroupsIfEmptyAndUpdatePortAddress(
                    node: node,
                    initialValue: rowObserver.getActiveValue(activeIndex: activeIndex),
                    unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                    unpackedPortIndex: unpackedPortIndex)
            }
        }
        
        self.outputViewModels.forEach {
            if let rowObserver = graph.getOutputRowObserver($0.id.asNodeIOCoordinate) {
                $0.updateFieldGroupsIfEmptyAndUpdatePortAddress(
                    node: node,
                    initialValue: rowObserver.getActiveValue(activeIndex: activeIndex),
                    // Not relevant for output row view models
                    unpackedPortParentFieldGroupType: nil,
                    unpackedPortIndex: nil)
            }
        }
        
        // Reset cache data--fixes scenarios like undo
//        self.viewCache?.needsUpdating = true
    }
    
    @MainActor
    func assignReference(node: NodeViewModel) {
        self.nodeDelegate = node
    }

    @MainActor
    var sizeByLocalBounds: CGSize? {
        self.viewCache?.sizeThatFits
    }
    
    @MainActor
    var locationOfInputs: CGPoint? {
        if let size = self.sizeByLocalBounds {
            // `node.center.x - node.width/2` = east face, where inputs are.
            return .init(x: self.position.x - size.width/2,
                         y: self.position.y)
        } else {
            return nil
        }
    }
    
    @MainActor
    var locationOfOutputs: CGPoint? {
        if let size = self.sizeByLocalBounds {
            // `node.center.x + node.width/2` = west face, where outputs are.
            return .init(x: self.position.x + size.width/2,
                         y: self.position.y)
        } else {
            return nil
        }
    }
    
    
    @MainActor
    var isMoving: Bool {
        self.position != self.previousPosition
    }

    @MainActor
    func updateVisibilityStatus(with newValue: Bool, graph: GraphState) {
        if newValue {
            self.updateAnchorPoints()
            self.nodeDelegate?.updatePortViewModels(graph)
        }
        
//        let oldValue = self.isVisibleInFrame
//        if oldValue != newValue {
//            self.isVisibleInFrame = newValue
//
//            // Refresh values if node back in frame
//            if newValue {
//                self.nodeDelegate?.updatePortViewModels()
//            }
//        }
    }
    
    @MainActor
    func shiftPosition(by gridLineLength: Int = SQUARE_SIDE_LENGTH) {
        let gridLineLength = CGFloat(gridLineLength)
        
        self.position = .init(
            x: self.position.x + gridLineLength,
            y: self.position.y + gridLineLength)
        
        self.previousPosition = self.position
    }
    
    
    @MainActor
    func resetViewSizingCache() {
        self.viewCache?.needsUpdating = true
    }
}

extension InputLayerNodeRowData {
    @MainActor
    static func empty(_ layerInputType: LayerInputType,
                      nodeId: UUID,
                      layer: Layer) -> Self {
        // Take the data from the schema!!
        let rowObserver = InputNodeRowObserver(values: [layerInputType.getDefaultValue(for: layer)],
                                               id: .init(portType: .keyPath(layerInputType),
                                                         nodeId: nodeId),
                                               upstreamOutputCoordinate: nil)
        return .init(rowObserver: rowObserver,
                     activeIndex: .defaultActiveIndex, // b/c empty i.e. fake
                     canvasObserver: nil)
    }
}
