//
//  CanvasItemViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LayerInputAddedToGraph: GraphEventWithResponse {
    
    let nodeId: NodeId
    let coordinate: LayerInputType
    
    func handle(state: GraphState) -> GraphResponse {
        
        log("LayerInputAddedToGraph: nodeId: \(nodeId)")
        log("LayerInputAddedToGraph: coordinate: \(coordinate)")
        
        guard let node = state.getNodeViewModel(nodeId),
              let input = node.getInputRowObserver(for: .keyPath(coordinate)) else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return .noChange
        }
        
        input.canvasUIData = .init(
            id: .init(),
            position: state.newNodeCenterLocation,
            zIndex: state.highestZIndex + 1)
        
        return .shouldPersist
    }
}


typealias CanvasItemId = UUID

@Observable
final class CanvasItemViewModel {
    // Needs its own identifier b/c 0 to many relationship with node
    var id: CanvasItemId
    
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
            guard let node = self.nodeDelegate,
                  let graph = self.graphDelegate else {
                log("NodeViewModel: isSelected: didSet: could not find graph delegate; cannot update port view data cache")
                return
            }
            
            updatePortColorDataUponNodeSelection(node: node,
                                                 graphState: graph)
        }
    }
    
    // Reference back to the parent node entity
    weak var nodeDelegate: NodeDelegate?
    
    var graphDelegate: GraphDelegate? {
        self.nodeDelegate?.graphDelegate
    }
    
    init(id: UUID,
         position: CGPoint,
         zIndex: Double,
         parentGroupNodeId: NodeId? = nil) {
        self.id = id
        self.position = position
        self.previousPosition = position
        self.bounds = bounds
        self.zIndex = zIndex
        self.parentGroupNodeId = parentGroupNodeId
        self.nodeDelegate = nodeDelegate
    }
}

extension CanvasItemViewModel {
    // Shouldn't be needed?
//    var kind: NodeKind? {
//        self.nodeDelegate?.kind
//    }
    
    var sizeByLocalBounds: CGSize {
        self.bounds.localBounds.size
    }
    
    // should be needed?
//    var isNodeMoving: Bool {
//    var isCanvasItemMoving: Bool {
//        self.position != self.previousPosition
//    }
    
    @MainActor
    static let fakeCanvasItem: CanvasItemViewModel = .init(
        id: fakeCanvasItemId,
        // So that we roughly get in the middle of the device screen;
        // (since we use
        position: .init(x: 350, y: 350),
        zIndex: 0,
        parentGroupNodeId: nil)
}

let fakeCanvasItemId: CanvasItemId = .init()

//extension CanvasItemViewModel: SchemaObserver {
//    func createSchema() -> CanvasNodeEntity {
//        .init(id: self.id,
//              position: self.position,
//              zIndex: self.zIndex,
//              parentGroupNodeId: self.parentGroupNodeId)
//    }
//    
//    @MainActor static func createObject(from entity: CanvasNodeEntity) -> Self {
//        .init(id: entity.id,
//              position: entity.position,
//              zIndex: entity.zIndex)
//    }
//    
//    @MainActor func update(from schema: CanvasNodeEntity) {
//        self.id = schema.id
//        self.position = schema.position
//        self.previousPosition = schema.position
//        self.zIndex = schema.zIndex
//        self.parentGroupNodeId = schema.parentGroupNodeId
//    }
//    
//    // TODO: remove -- CanvasItem represents data that is never changed by graph reset
//    func onPrototypeRestart() { }
//}

