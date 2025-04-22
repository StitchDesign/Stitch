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
    
    
    // MARK: cached ui-data derived from underlying row observer
    
    @MainActor var cachedActiveValue: PortValue
    @MainActor var cachedFieldValueGroups = FieldGroupList()
        
    // MARK: data specific to a draggable port on the canvas; not derived from underlying row observer and not applicable to row view models in the inspector
    @MainActor var portUIViewModel: OutputPortUIViewModel
    
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
        
        self.portUIViewModel = .init(id: OutputCoordinate(portId: id.portId,
                                                   nodeId: id.nodeId))
        self.id = id
        self.cachedActiveValue = initialValue
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
    }
}

extension OutputNodeRowObserver {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        self.getDownstreamCanvasItemsIds()
    }
}
