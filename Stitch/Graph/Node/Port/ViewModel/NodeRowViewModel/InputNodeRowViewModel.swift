//
//  InputNodeRowViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation

// UI data
@Observable
final class InputNodeRowViewModel: NodeRowViewModel {
    typealias PortAddressType = InputPortIdAddress
    
    static let nodeIO: NodeIO = .input
    
    let id: NodeRowViewModelId
    
    @MainActor var viewCache: NodeLayoutCache?
    
    // MARK: cached ui-data derived from underlying row observer
    
    @MainActor var cachedActiveValue: PortValue
    @MainActor var cachedFieldValueGroups = FieldGroupList()
    @MainActor var connectedCanvasItems: Set<CanvasItemId> = .init()
    
    
    // MARK: data specific to a draggable port on the canvas; not derived from underlying row observer and not applicable to row view models in the inspector
    
    @MainActor var anchorPoint: CGPoint?
    @MainActor var portColor: PortColor = .noEdge
    @MainActor var isDragging = false
    @MainActor var portViewData: PortAddressType?
    
    
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
        self.id = id
        self.cachedActiveValue = initialValue
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
    }
}

extension InputNodeRowViewModel {
    @MainActor
    func findConnectedCanvasItems(rowObserver: InputNodeRowObserver) -> CanvasItemIdSet {
        // Does this input row observer has an upstream connection?
        guard let upstreamOutputObserver = rowObserver.upstreamOutputObserver,
              // If so, find that row view model
              let upstreamNodeRowViewModel = upstreamOutputObserver.nodeRowViewModel,
              let upstreamId = upstreamNodeRowViewModel.canvasItemDelegate?.id else {
            return .init()
        }
        
        return Set([upstreamId])
    }
    
    @MainActor
    func calculatePortColor(hasEdge: Bool,
                            hasLoop: Bool,
                            selectedEdges: Set<PortEdgeUI>,
                            selectedCanvasItems: CanvasItemIdSet,
                            drawingObserver: EdgeDrawingObserver) -> PortColor {
        
        guard let canvasItemId = self.id.graphItemType.getCanvasItemId else {
//            let selectedCanvasItems = self.graphDelegate?.selection.selectedCanvasItems else {
            fatalErrorIfDebug() // called incorrectly
            return .noEdge
        }
        
        // Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
        let canvasItemIsSelected = selectedCanvasItems.contains(canvasItemId)
        let isSelected = canvasItemIsSelected || self.isConnectedToASelectedCanvasItem(selectedCanvasItems) || self.hasSelectedEdge(selectedEdges: selectedEdges)
        
        return PortColor(isSelected: isSelected,
                         hasEdge: hasEdge,
                         hasLoop: hasLoop)
    }
    
    @MainActor
    func hasSelectedEdge(selectedEdges: Set<PortEdgeUI>) -> Bool {
        guard let portViewData = self.portViewData else {
            return false
        }
        return selectedEdges.contains { $0.to == portViewData }
    }
}
