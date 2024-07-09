//
//  CanvasItemViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum CanvasItemId: Hashable {
    case node(NodeId)
    case layerInputOnGraph(LayerInputCoordinate)
    case layerOutputOnGraph(LayerOutputCoordinate)
    
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
        case .layerInputOnGraph(let layerInputOnGraphId):
            return layerInputOnGraphId
        default:
            return nil
        }
    }
    
    var layerOutputCase: LayerOutputCoordinate? {
        switch self {
        case .layerOutputOnGraph(let layerOutputOnGraphId):
            return layerOutputOnGraphId
        default:
            return nil
        }
    }
}

extension CanvasItemId: Identifiable {
    var id: Int {
        self.hashValue
    }
}

protocol LayerCoordinate: Hashable {
    // id for the parent layer node
    var node: NodeId  { get set }
    
    // the keypath, i.e. unique port
    var keyPath: LayerInputType { get set }
}

// TODO: careful for perf here?
/// Canvas can only contain at most 1 LayerInputOnGraph per a given layer node's unique port.
struct LayerInputCoordinate: LayerCoordinate {
    var node: NodeId // id for the parent layer node
    var keyPath: LayerInputType // the keypath, i.e. unique port
    
    var asInputCoordinate: InputCoordinate {
        .init(portType: .keyPath(keyPath),
              nodeId: node)
    }
}

struct LayerOutputCoordinate: LayerCoordinate {
    var node: NodeId // id for the parent layer node
    var portId: Int
}

typealias CanvasItemViewModels = [CanvasItemViewModel]

@Observable
final class CanvasItemViewModel: Identifiable {
    var id: CanvasItemId
    var position: CGPoint = .zero
    var previousPosition: CGPoint = .zero
    var bounds = NodeBounds()
    var zIndex: Double = .zero
    var parentGroupNodeId: NodeId?
    
    // Default to false so initialized graphs don't take on extra perf loss
    var isVisibleInFrame = false
    
//    // View specific port value data
//    var inputViewModels: [InputNodeRowViewModel]
//    var outputViewModels: [OutputNodeRowViewModel]
    
    // Moved state here for render cycle perf on port view for colors
    @MainActor
    var isSelected: Bool = false {
        didSet {
            guard let node = self.nodeDelegate,
                  let graph = self.graphDelegate else {
                log("CanvasItemViewModel: isSelected: didSet: could not find node and/or graph delegate; cannot update port view data cache")
                return
            }
            
            updatePortColorDataUponNodeSelection(node: node,
                                                 graphState: graph)
            
            if node.kind == .group {
                updatePortColorDataUponNodeSelection(
                    inputs: graph.getSplitterRowObservers(for: node.id, type: .input),
                    outputs: graph.getSplitterRowObservers(for: node.id, type: .output),
                    graphState: graph)
            }
        }
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
         nodeDelegate: NodeDelegate?) {
        self.id = id
        self.position = position
        self.previousPosition = position
        self.bounds = bounds // where or how is this set?
        self.zIndex = zIndex
        self.parentGroupNodeId = parentGroupNodeId
        self.nodeDelegate = nodeDelegate // where or how is this set?
    }
}

extension CanvasItemViewModel: SchemaObserver {
    convenience init(from canvasEntity: CanvasNodeEntity,
                     id: CanvasItemId,
                     node: NodeDelegate?) {
        self.id = id
        self.position = canvasEntity.position
        self.previousPosition = canvasEntity.position
        self.zIndex = canvasEntity.zIndex
        self.parentGroupNodeId = canvasEntity.parentGroupNodeId
        self.nodeDelegate = node
    }
    
    func createSchema() -> CanvasNodeEntity {
        .init(position: self.position,
              zIndex: self.zIndex,
              parentGroupNodeId: self.parentGroupNodeId)
    }

    @MainActor func update(from schema: CanvasNodeEntity) {
        // Note: `mutating func setOnChange` cases Observable re-render even when no-op; see Playgrounds demo
//        self.id.setOnChange(schema.id)
        
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
    var sizeByLocalBounds: CGSize {
        self.bounds.localBounds.size
    }
    
    var isMoving: Bool {
        self.position != self.previousPosition
    }

    @MainActor
    func updateVisibilityStatus(with newValue: Bool,
                                activeIndex: ActiveIndex) {
        let oldValue = self.isVisibleInFrame
        if oldValue != newValue {
            self.isVisibleInFrame = newValue

            if self.nodeDelegate?.kind == .group {
                // Group node needs to mark all input and output splitters as visible
                // Fixes issue for setting visibility on groups
                let inputsObservers = self.nodeDelegate?.getAllInputsObservers() ?? []
                let outputsObservers = self.nodeDelegate?.getAllOutputsObservers() ?? []
                let allObservers = inputsObservers + outputsObservers
                allObservers
                    .flatMap { $0.nodeDelegate?.getAllCanvasObservers() ?? [] }
                    .forEach { $0.isVisibleInFrame = newValue }
            }

            // Refresh values if node back in frame
            if newValue {
                self.nodeDelegate?
                    .updateRowObservers(activeIndex: activeIndex)
            }
        }
    }
    
//    @MainActor var allRowViewModels: [any NodeRowViewModel] {
//        self.inputViewModels + self.outputViewModels
//    }
    
    // @MainActor
    // static let fakeCanvasItemForLayerInputOnGraph: CanvasItemViewModel = .init(
    //     id: fakeCanvasItemIdForLayerInputOnGraph,
    //     // So that we roughly get in the middle of the device screen;
    //     // (since we use
    //     position: .init(x: 350, y: 350),
    //     zIndex: 0,
    //     parentGroupNodeId: nil,
    //     nodeDelegate: nil)
}

// let fakeCanvasItemIdForLayerInputOnGraph: CanvasItemId = .layerInputOnGraph(.init(
//     node: .fakeNodeId,
//     keyPath: .size))


extension LayerNodeRowData {
    @MainActor
    static func empty(_ layerInputType: LayerInputType,
                      layer: Layer) -> Self {
        let rowObserver = NodeRowObserver(values: [layerInputType.getDefaultValue(for: layer)],
                                          nodeKind: .layer(.rectangle),
                                          userVisibleType: nil,
                                          id: .init(portId: -1, nodeId: .init()),
                                          activeIndex: .init(.zero),
                                          upstreamOutputCoordinate: nil,
                                          nodeIOType: .input,
                                          nodeDelegate: nil)
        
        fatalError()
        
        // TODO: update arguments above to pass in the entity struct for canvas data
//        let canvasObserver = CanvasItemViewModel(from canvasEntity: ....)
//        return .init(rowObserver: rowObserver,
//                     canvasObsever: canvasObserver)
    }
}
