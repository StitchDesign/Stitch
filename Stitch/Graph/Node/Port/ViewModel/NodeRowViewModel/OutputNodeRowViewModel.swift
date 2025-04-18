//
//  OutputNodeRowViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation


@Observable
final class OutputNodeRowViewModel: NodeRowViewModel {
    typealias PortAddressType = OutputPortIdAddress
    
    static let nodeIO: NodeIO = .output

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
    @MainActor weak var rowDelegate: OutputNodeRowObserver?
    
    /*
     // Can an inspector output-row ever have a canvas item delegate ? Or would a "layer output on the graph" be represented as a non-nil canvas item reference on the `OutputLayerNodeRowData` ?
     // i.e. is this `canvasItemDelegate` only for
     
     
     */
    @MainActor weak var canvasItemDelegate: CanvasItemViewModel?
    
    init(id: NodeRowViewModelId,
         initialValue: PortValue,
         rowDelegate: OutputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.cachedActiveValue = initialValue
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
    }
}

extension OutputNodeRowViewModel {
    @MainActor
    func findConnectedCanvasItems(rowObserver: OutputNodeRowObserver) -> CanvasItemIdSet {
        rowObserver.getDownstreamCanvasItemsIds()
    }
    
    /// Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
    /// An actively-drawn edge's color is determined only by:
    /// 1. "Do we have a loop?" (blue vs theme-color) and
    /// 2. "Do we have an eligible input?" (highlight vs non-highlighted)
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
        
        if let drawnEdge = drawingObserver.drawingGesture,
           drawnEdge.output.id == self.id {
            let hasEligibleInput = drawingObserver.nearestEligibleInput.isDefined
            return PortColor(isSelected: hasEligibleInput,
                             hasEdge: hasEligibleInput,
                             hasLoop: hasLoop)
        }
        
        // Otherwise, common port color logic applies:
        else {
            let canvasItemIsSelected = selectedCanvasItems.contains(canvasItemId)
            let isSelected = canvasItemIsSelected || self.isConnectedToASelectedCanvasItem(selectedCanvasItems) || self.hasSelectedEdge(selectedEdges: selectedEdges)
            
            return PortColor(isSelected: isSelected,
                             hasEdge: hasEdge,
                             hasLoop: hasLoop)
        }
    }
    
    @MainActor
    func hasSelectedEdge(selectedEdges: Set<PortEdgeUI>) -> Bool {
        guard let portViewData = self.portViewData else {
            return false
        }
        return selectedEdges.contains { $0.from == portViewData }
    }
}
