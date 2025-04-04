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
    typealias PortViewType = InputPortViewData
    
    static let nodeIO: NodeIO = .input
    
    let id: NodeRowViewModelId
    @MainActor var viewCache: NodeLayoutCache?
    @MainActor var activeValue: PortValue = .number(.zero)
    @MainActor var fieldValueTypes = FieldGroupTypeDataList()
    @MainActor var connectedCanvasItems: Set<CanvasItemId> = .init()
    @MainActor var anchorPoint: CGPoint?
    @MainActor var portColor: PortColor = .noEdge
    @MainActor var isDragging = false
    @MainActor var portViewData: PortViewType?
    @MainActor weak var nodeDelegate: NodeDelegate?
    @MainActor weak var rowDelegate: InputNodeRowObserver?
    
    // TODO: input node row view model for an inspector should NEVER have canvasItemDelegate
    @MainActor weak var canvasItemDelegate: CanvasItemViewModel? // also nil when the layer input is not on the canvas
    
    // TODO: temporary property for old-style layer nodes
    @MainActor var layerPortId: Int?
    
    @MainActor
    init(id: NodeRowViewModelId,
         rowDelegate: InputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
    }
}

extension InputNodeRowViewModel {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        guard let upstreamOutputObserver = self.rowDelegate?.upstreamOutputObserver,
              let upstreamNodeRowViewModel = upstreamOutputObserver.nodeRowViewModel,
              let upstreamId = upstreamNodeRowViewModel.canvasItemDelegate?.id else {
            return .init()
        }
        
        return Set([upstreamId])
    }
    
    @MainActor
    func calculatePortColor() -> PortColor {
        let isEdgeSelected = self.hasSelectedEdge()
        
        // Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
        let isSelected = self.isCanvasItemSelected ||
            self.isConnectedToASelectedCanvasItem ||
            isEdgeSelected
        return .init(isSelected: isSelected,
                     hasEdge: hasEdge,
                     hasLoop: hasLoop)
    }
    
    @MainActor
    func hasSelectedEdge() -> Bool {
        guard let portViewData = portViewData,
              let graphDelegate = graphDelegate else {
            return false
        }
        
        return graphDelegate.selectedEdges.contains { $0.to == portViewData }
    }
}
