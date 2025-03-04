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
    @MainActor var activeValue: PortValue = .number(.zero)
    @MainActor var fieldValueTypes = FieldGroupTypeDataList<OutputFieldViewModel>()
    @MainActor var connectedCanvasItems: Set<CanvasItemId> = .init()
    @MainActor var anchorPoint: CGPoint?
    @MainActor var portColor: PortColor = .noEdge
    @MainActor var isDragging = false
    @MainActor var portViewData: PortViewType?
    @MainActor weak var nodeDelegate: NodeDelegate?
    @MainActor weak var rowDelegate: OutputNodeRowObserver?
    @MainActor weak var canvasItemDelegate: CanvasItemViewModel?
    
    init(id: NodeRowViewModelId,
         rowDelegate: OutputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
    }
}

extension OutputNodeRowViewModel {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        guard let downstreamCanvases = self.rowDelegate?.getConnectedDownstreamNodes() else {
            return .init()
        }
            
        let downstreamCanvasIds = downstreamCanvases.map { $0.id }
        return Set(downstreamCanvasIds)
    }
    
    /// Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
    /// An actively-drawn edge's color is determined only by:
    /// 1. "Do we have a loop?" (blue vs theme-color) and
    /// 2. "Do we have an eligible input?" (highlight vs non-highlighted)
    @MainActor
    func calculatePortColor() -> PortColor {
        if let drawingObserver = self.graphDelegate?.edgeDrawingObserver,
           let drawnEdge = drawingObserver.drawingGesture,
           drawnEdge.output.id == self.id {
            return PortColor(
                isSelected: drawingObserver.nearestEligibleInput.isDefined,
//                hasEdge: hasEdge,
                hasEdge: drawingObserver.nearestEligibleInput.isDefined,
                hasLoop: hasLoop)
        }
        
        
        // Otherwise, common port color logic applies:
        else {
            let isSelected = self.isCanvasItemSelected ||
                self.isConnectedToASelectedCanvasItem ||
            self.hasSelectedEdge()
            return PortColor(isSelected: isSelected,
                             hasEdge: hasEdge,
                             hasLoop: hasLoop)
        }
    }
    
    @MainActor func hasSelectedEdge() -> Bool {
        guard let portViewData = portViewData,
              let graphDelegate = graphDelegate else {
            return false
        }
        
        return graphDelegate.selectedEdges.contains { $0.from == portViewData }
    }
}
