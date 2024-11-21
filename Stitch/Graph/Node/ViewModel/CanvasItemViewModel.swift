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
final class CanvasItemViewModel: Identifiable, StitchLayoutCachable {
    var id: CanvasItemId
    var position: CGPoint = .zero
    var previousPosition: CGPoint = .zero
    var zIndex: Double = .zero
    var parentGroupNodeId: NodeId?
    
    var isVisibleInFrame: Bool {
        guard let graph = self.graphDelegate else { return false }
        return graph.visibleNodesViewModel.visibleCanvasIds.contains(self.id)
    }
    
    // View specific port value data
    var inputViewModels: [InputNodeRowViewModel] = []
    var outputViewModels: [OutputNodeRowViewModel] = []
    
    // Cached subview sizes for performance gains in commit phase
    var viewCache: NodeLayoutCache?
    
    // Moved state here for render cycle perf on port view for colors
    @MainActor
    var isSelected: Bool {
        guard let graphDelegate = self.graphDelegate else { return false }
        return graphDelegate.graphUI.selection.selectedNodeIds.contains(self.id)
    }
    
    // Reference back to the parent node entity
    weak var nodeDelegate: NodeDelegate?
    
    var graphDelegate: GraphDelegate? {
        self.nodeDelegate?.graphDelegate
    }
    
    init(id: CanvasItemId,
         position: CGPoint,
         zIndex: Double,
         parentGroupNodeId: NodeId?,
         inputRowObservers: [InputNodeRowObserver],
         outputRowObservers: [OutputNodeRowObserver],
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         nodeDelegate: NodeDelegate? = nil) {
        self.id = id
        self.position = position
        self.previousPosition = position
        self.zIndex = zIndex
        self.parentGroupNodeId = parentGroupNodeId
        self.nodeDelegate = nodeDelegate
        
        // Instantiate input and output row view models
        self.syncRowViewModels(inputRowObservers: inputRowObservers,
                               outputRowObservers: outputRowObservers,
                               unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                               unpackedPortIndex: unpackedPortIndex)
    }
}

extension CanvasItemViewModel {
    func syncRowViewModels(inputRowObservers: [InputNodeRowObserver],
                           outputRowObservers: [OutputNodeRowObserver],
                           unpackedPortParentFieldGroupType: FieldGroupType?,
                           unpackedPortIndex: Int?) {
        
        self.inputViewModels.sync(with: inputRowObservers,
                                  canvas: self,
                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                  unpackedPortIndex: unpackedPortIndex)
        
        self.outputViewModels.sync(with: outputRowObservers,
                                   canvas: self,
                                   unpackedPortParentFieldGroupType: nil,
                                   unpackedPortIndex: nil)
    }
    
    // Only called at project open?
    convenience init(from canvasEntity: CanvasNodeEntity,
                     id: CanvasItemId,
                     inputRowObservers: [InputNodeRowObserver],
                     outputRowObservers: [OutputNodeRowObserver],
                     unpackedPortParentFieldGroupType: FieldGroupType?,
                     unpackedPortIndex: Int?) {
        self.init(id: id,
                  position: canvasEntity.position,
                  zIndex: canvasEntity.zIndex,
                  parentGroupNodeId: canvasEntity.parentGroupNodeId,
                  inputRowObservers: inputRowObservers,
                  outputRowObservers: outputRowObservers,
                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                  unpackedPortIndex: unpackedPortIndex)
    }
    
    func createSchema() -> CanvasNodeEntity {        
        .init(position: self.position,
              zIndex: self.zIndex,
              parentGroupNodeId:self.parentGroupNodeId)
    }

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
    }
    
    func onPrototypeRestart() { }
}

extension CanvasItemViewModel {
    @MainActor
    func initializeDelegate(_ node: NodeDelegate,
                            unpackedPortParentFieldGroupType: FieldGroupType?,
                            unpackedPortIndex: Int?) {
        self.nodeDelegate = node
        self.inputViewModels.forEach {
            $0.initializeDelegate(node,
                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                  unpackedPortIndex: unpackedPortIndex)
        }
        
        self.outputViewModels.forEach {
            $0.initializeDelegate(node,
                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                  unpackedPortIndex: unpackedPortIndex)
        }
        
        // Reset cache data--fixes scenarios like undo
        self.viewCache = nil
    }
        
    var sizeByLocalBounds: CGSize {
        self.viewCache?.sizeThatFits ?? .zero
    }
    
    var isMoving: Bool {
        self.position != self.previousPosition
    }

    @MainActor
    func updateVisibilityStatus(with newValue: Bool) {
        self.updatePortLocations()
        self.nodeDelegate?.updatePortViewModels()
        
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
    
    func shiftPosition(by gridLineLength: Int = SQUARE_SIDE_LENGTH) {
        let gridLineLength = CGFloat(gridLineLength)
        
        self.position = .init(
            x: self.position.x + gridLineLength,
            y: self.position.y + gridLineLength)
        
        self.previousPosition = self.position
    }
    
    /// Updates location of anchor points.
    @MainActor
    func updatePortLocations() {
        self.inputViewModels.forEach {
            $0.updateAnchorPoint()
        }
        self.outputViewModels.forEach {
            $0.updateAnchorPoint()
        }
    }
    
    func resetViewSizingCache() {
        self.viewCache = nil
    }
}

extension InputLayerNodeRowData {
    static func empty(_ layerInputType: LayerInputType,
                      layer: Layer) -> Self {
        // Take the data from the schema!! 
        let rowObserver = InputNodeRowObserver(values: [layerInputType.getDefaultValue(for: layer)],
                                               nodeKind: .layer(layer),
                                               userVisibleType: nil,
                                               id: .init(portType: .keyPath(layerInputType),
                                                         nodeId: .init()),
                                               upstreamOutputCoordinate: nil)
        return .init(rowObserver: rowObserver,
                     canvasObserver: nil)
    }
}
