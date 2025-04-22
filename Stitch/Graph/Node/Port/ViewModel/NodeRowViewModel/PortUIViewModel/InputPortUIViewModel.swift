//
//  InputPortUIData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/21/25.
//

import Foundation


// May want a common protocol differentiated by `portAddress` type
@Observable
final class InputPortUIViewModel: PortUIViewModel {
    
    let id: InputCoordinate // which node id + port id this is for
    
    // the portDragged and portDragEnded methods DO require specific input vs output row view model;
    // so instead you can pass down the nodeIO and the
    @MainActor var anchorPoint: CGPoint? = nil
    @MainActor var portColor: PortColor = .noEdge
    @MainActor var portAddress: InputPortIdAddress?
    @MainActor var connectedCanvasItems = CanvasItemIdSet()
    
    @MainActor
    init(id: InputCoordinate,
         anchorPoint: CGPoint? = nil,
         portColor: PortColor = .noEdge,
         portAddress: InputPortIdAddress? = nil,
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
    var inputPortUIViewModels: [InputPortUIViewModel] {
        self.inputViewModels.map(\.portUIViewModel)
    }
}

extension InputNodeRowObserver {
    @MainActor
    var allPortUIViewModels: [InputPortUIViewModel] {
        self.allRowViewModels.map(\.portUIViewModel)
    }
}

extension InputPortUIViewModel {
    
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
