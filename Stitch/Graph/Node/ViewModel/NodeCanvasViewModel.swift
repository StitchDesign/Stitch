//
//  NodeCanvasViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit



@Observable
final class NodeCanvasViewModel {
    // Needs its own identifier b/c 0 to many relationship with node
    let id: UUID
    
    var position: CGPoint = .zero
    var previousPosition: CGPoint = .zero
    var bounds = NodeBounds()
    var zIndex: Double = .zero
    var parentGroupNodeId: NodeId?
    
    // Default to false so initialized graphs don't take on extra perf loss
    var isVisibleInFrame = false
    
    // Moved state here for render cycle perf on port view for colors
    @MainActor
    var isSelected: Bool = false {
        didSet {
            guard let graph = graphDelegate else {
                log("NodeViewModel: isSelected: didSet: could not find graph delegate; cannot update port view data cache")
                return
            }
            
            // Move to didSet ?
            updatePortColorDataUponNodeSelection(node: self,
                                                 graphState: graph)
            
            // When a group node is selected, we also update the port view cache of its splitters.
            if self.kind == .group {
                updatePortColorDataUponNodeSelection(
                    inputs: graph.getSplitterRowObservers(for: self.id, type: .input),
                    outputs: graph.getSplitterRowObservers(for: self.id, type: .output),
                    graphState: graph)
            }
        }
    }
    
    // Reference back to the parent node entity
    weak var nodeDelegate: NodeDelegate?
    
    init(id: UUID,
         position: CGPoint,
         zIndex: Double,
         parentGroupNodeId: NodeId? = nil,
         title: String,
         nodeKind: NodeKind) {
        self.id = id
        self.position = position
        self.previousPosition = position
        self.bounds = bounds
        self.zIndex = zIndex
        self.parentGroupNodeId = parentGroupNodeId
        self.nodeDelegate = nodeDelegate
    }
}

extension NodeCanvasViewModel: SchemaObserver {
    func onPrototypeRestart() { }
}

extension NodeCanvasViewModel {
    var kind: NodeKind? {
        self.nodeDelegate?.kind
    }
    
    var sizeByLocalBounds: CGSize {
        self.bounds.localBounds.size
    }
    
    var isNodeMoving: Bool {
        self.position != self.previousPosition
    }
}

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
//        let canvasObserver = NodeCanvasViewModel(from canvasEntity: ....)
//        return .init(rowObserver: rowObserver,
//                     canvasObsever: canvasObserver)
    }
}
