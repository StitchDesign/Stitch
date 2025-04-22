//
//  OutputPortUIData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/21/25.
//

import Foundation

// May want a common protocol differentiated by `portAddress` type
@Observable
final class OutputPortUIViewModel: PortUIViewModel {
    
    let id: OutputCoordinate // which node id + port id this is for
    
    @MainActor var anchorPoint: CGPoint? = nil
    @MainActor var portColor: PortColor = .noEdge
    @MainActor var portAddress: OutputPortIdAddress?
    @MainActor var connectedCanvasItems = CanvasItemIdSet()
    
    @MainActor
    init(id: OutputCoordinate,
         anchorPoint: CGPoint? = nil,
         portColor: PortColor = .noEdge,
         portAddress: OutputPortIdAddress? = nil,
         connectedCanvasItems: CanvasItemIdSet = .init()) {
        self.id = id
        self.anchorPoint = anchorPoint
        self.portColor = portColor
        self.portAddress = portAddress
        self.connectedCanvasItems = connectedCanvasItems
    }
}

extension CanvasItemViewModel {
    @MainActor
    var outputPortUIViewModels: [OutputPortUIViewModel] {
        self.outputViewModels.map(\.portUIViewModel)
    }
}

extension OutputNodeRowObserver {
    @MainActor
    var allPortUIViewModels: [OutputPortUIViewModel] {
        self.allRowViewModels.map(\.portUIViewModel)
    }
}

extension OutputPortUIViewModel {
    /// Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
    /// An actively-drawn edge's color is determined only by:
    /// 1. "Do we have a loop?" (blue vs theme-color) and
    /// 2. "Do we have an eligible input?" (highlight vs non-highlighted)
    @MainActor
    func calculatePortColor(canvasItemId: CanvasItemId,
                            hasEdge: Bool,
                            hasLoop: Bool,
                            selectedEdges: Set<PortEdgeUI>,
                            selectedCanvasItems: CanvasItemIdSet,
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
            let canvasItemIsSelected = selectedCanvasItems.contains(canvasItemId)
            let isSelected = canvasItemIsSelected || self.isConnectedToASelectedCanvasItem(selectedCanvasItems) || self.hasSelectedEdge(selectedEdges: selectedEdges)
            
            return PortColor(isSelected: isSelected,
                             hasEdge: hasEdge,
                             hasLoop: hasLoop)
        }
    }
    
    @MainActor
    func hasSelectedEdge(selectedEdges: Set<PortEdgeUI>) -> Bool {
        guard let portViewData = self.portAddress else {
            return false
        }
        return selectedEdges.contains { $0.from == portViewData }
    }
}
