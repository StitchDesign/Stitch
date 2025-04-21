//
//  InputNodeRowViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation


@Observable
final class InputNodeRowViewModel: NodeRowViewModel {
    
    typealias PortAddressType = InputPortIdAddress
    
    static let nodeIO: NodeIO = .input
    
    let id: NodeRowViewModelId
        
    // MARK: cached ui-data derived from underlying row observer
    
    @MainActor var cachedActiveValue: PortValue
    @MainActor var cachedFieldValueGroups = FieldGroupList()
    
    // MARK: data specific to a draggable port on the canvas; not derived from underlying row observer and not applicable to row view models in the inspector
    @MainActor var portData: InputPortUIData
    
    // MARK: delegates, weak references to parents
    
    @MainActor weak var nodeDelegate: NodeViewModel?
    @MainActor weak var rowDelegate: InputNodeRowObserver?
    
    // TODO: input node row view model for an inspector should NEVER have canvasItemDelegate
    @MainActor weak var canvasItemDelegate: CanvasItemViewModel? // also nil when the layer input is not on the canvas
    
    @MainActor
    init(id: NodeRowViewModelId,
         initialValue: PortValue,
         rowDelegate: InputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.portData = .init(id: InputCoordinate(portId: id.portId,
                                                  nodeId: id.nodeId))
        self.id = id
        self.cachedActiveValue = initialValue
        self.nodeDelegate = nodeDelegate // This is referencing the object itself, already !?
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
      
    }
}

extension InputNodeRowObserver {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        // Does this input row observer has an upstream connection (i.e. output observer)?
        // If so, return that observer's canvas item id
        if let upstreamId = self.upstreamOutputObserver?.nodeRowViewModel?.canvasItemDelegate?.id {
            return .init([upstreamId])
        } else {
            return .init()
        }
    }
}

extension InputNodeRowViewModel {
    
    @MainActor
    func calculatePortColor(canvasItemId: CanvasItemId,
                            hasEdge: Bool,
                            hasLoop: Bool,
                            selectedEdges: Set<PortEdgeUI>,
                            selectedCanvasItems: CanvasItemIdSet,
                            drawingObserver: EdgeDrawingObserver) -> PortColor {
                
        // Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
        let canvasItemIsSelected = selectedCanvasItems.contains(canvasItemId)
        let isSelected = canvasItemIsSelected ||
        
        // Relies on self.connectedCanvasItems
        self.isConnectedToASelectedCanvasItem(selectedCanvasItems)
        
        // Relies on self.portViewData
        || self.hasSelectedEdge(selectedEdges: selectedEdges)
        
        return PortColor(isSelected: isSelected,
                         hasEdge: hasEdge,
                         hasLoop: hasLoop)
    }
    
    @MainActor
    func hasSelectedEdge(selectedEdges: Set<PortEdgeUI>) -> Bool {
        guard let portViewData = self.portAddress else {
            return false
        }
        return selectedEdges.contains { $0.to == portViewData }
    }
}
