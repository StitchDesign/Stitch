//
//  PortUIViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/22/25.
//

import Foundation

protocol PortUIViewModel: Observable, Identifiable, AnyObject, Sendable {
    associatedtype PortAddressType: PortIdAddress
    
    // Which
    var id: NodeIOCoordinate { get }
    
    // TODO: add `canvasItemId`, since PortUIViewModel is only for a canvas item
        
    @MainActor var anchorPoint: CGPoint? { get set }
    @MainActor var portColor: PortColor { get set }
    @MainActor var portAddress: PortAddressType? { get set }
    @MainActor var connectedCanvasItems: CanvasItemIdSet { get set }
    
    // Entrypoint for updating an input or output port's color, often when we don't know whether we specifically have an input or an output.
    // Relies on row VM's non-nil canvas id, portViewData, connectedCanvasItems
    @MainActor func calculatePortColor(
        // Restriction on type of row view model (canvas only, never inspector)
        canvasItemId: CanvasItemId,
        
        // Facts from the underlying row observer
        hasEdge: Bool,
        hasLoop: Bool,
        
        // Facts from the graph
        selectedEdges: Set<PortEdgeUI>,
        selectedCanvasItems: CanvasItemIdSet,
        // output only
        drawingObserver: EdgeDrawingObserver
    ) -> PortColor
}

extension PortUIViewModel {
    
    // AnchorPoint logic relies on numbered ports, but layers have keyPaths (names rather than ints).
    // Since a layer input/field on the canvas is always a single 'row', we can assume portId=0 for AnchorPoint purposes.
    var portIdForAnchorPoint: Int {
        self.id.portId ?? 0
    }
    
    @MainActor
    func isConnectedToASelectedCanvasItem(_ selectedCanvasItems: CanvasItemIdSet) -> Bool {
        for connectedCanvasItemId in self.connectedCanvasItems {
            if selectedCanvasItems.contains(connectedCanvasItemId) {
                // Found connected canvas item that is selected
                return true
            }
        }
        return false
    }
}
