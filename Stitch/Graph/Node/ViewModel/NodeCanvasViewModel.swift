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
    
    var position: CGPoint = .zero
    var previousPosition: CGPoint = .zero
    var bounds = NodeBounds()
    var zIndex: Double = .zero
    var parentGroupNodeId: NodeId?
    
    // Default to false so initialized graphs don't take on extra perf loss
    var isVisibleInFrame = false
    
    var title: String {
        didSet(oldValue) {
            if oldValue != title {
                self._cachedDisplayTitle = self.getDisplayTitle()
            }
        }
    }
    
    /*
     human-readable-string is perf-intensive, so we cache the node title.

     Previously we used a `lazy var`, but since Swift never recalculates lazy vars we had to switch to a cache.
     */
    private var _cachedDisplayTitle: String = ""
    
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
    
    init(position: CGPoint,
         zIndex: Double,
         parentGroupNodeId: NodeId? = nil,
         title: String,
         nodeKind: NodeKind) {
        self.position = position
        self.previousPosition = position
        self.bounds = bounds
        self.zIndex = zIndex
        self.parentGroupNodeId = parentGroupNodeId
        self.title = title
        self.nodeDelegate = nodeDelegate
        
        self._cachedDisplayTitle = self.getDisplayTitle()
    }
}

extension NodeCanvasViewModel: SchemaObserver {
    func onPrototypeRestart() { }
}

extension NodeCanvasViewModel {
    var kind: NodeKind? {
        self.nodeDelegate?.kind
    }
    
    func getDisplayTitle() -> String {
        guard let kind = self.kind else {
            return ""
        }
        
        return self.getDisplayTitle(kind: kind)
    }
    
    // MARK: heavy perf cost due to human readable strings.**
    func getDisplayTitle(kind: NodeKind) -> String {
        // always prefer a custom name
        kind.getDisplayTitle(customName: self.title)
    }
    
    var sizeByLocalBounds: CGSize {
        self.bounds.localBounds.size
    }
    
    var displayTitle: String {
        guard self.id != Self.nilChoice.id else {
            return "None"
        }
        
        return self._cachedDisplayTitle
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
