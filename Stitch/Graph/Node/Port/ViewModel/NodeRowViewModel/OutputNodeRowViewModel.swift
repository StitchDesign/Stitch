//
//  OutputNodeRowViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation


@Observable
final class OutputNodeRowViewModel: NodeRowViewModel {
    typealias PortViewType = OutputPortViewData
    
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
    @MainActor var portViewData: PortViewType?
    
    
    // MARK: delegates, weak references to parents
    
    @MainActor weak var nodeDelegate: NodeViewModel?
    @MainActor weak var rowDelegate: OutputNodeRowObserver?
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
        let downstreamCanvases = rowObserver.getConnectedDownstreamNodes()
        let downstreamCanvasIds = downstreamCanvases.map { $0.id }
        return Set(downstreamCanvasIds)
    }
    
    /// Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
    /// An actively-drawn edge's color is determined only by:
    /// 1. "Do we have a loop?" (blue vs theme-color) and
    /// 2. "Do we have an eligible input?" (highlight vs non-highlighted)
    @MainActor
    func calculatePortColor(hasEdge: Bool,
                            hasLoop: Bool,
                            selectedEdges: Set<PortEdgeUI>,
                            drawingObserver: EdgeDrawingObserver) -> PortColor {
        
        if let drawnEdge = drawingObserver.drawingGesture,
           drawnEdge.output.id == self.id {
            let hasEligibleInput = drawingObserver.nearestEligibleInput.isDefined
            return PortColor(isSelected: hasEligibleInput,
                             hasEdge: hasEligibleInput,
                             hasLoop: hasLoop)
        }
        
        // Otherwise, common port color logic applies:
        else {
            let isSelected = self.isCanvasItemSelected ||
                self.isConnectedToASelectedCanvasItem ||
            self.hasSelectedEdge(selectedEdges: selectedEdges)
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
