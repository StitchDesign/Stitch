//
//  OutputNodeRowViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation

@Observable
final class OutputNodeRowViewModel: NodeRowViewModel {
    
    static let nodeIO: NodeIO = .output

    let id: NodeRowViewModelId
        
    // Cached ui-data derived from underlying row observer
    @MainActor var fieldsUIViewModel: RowFieldsUIViewModel
        
    // Specific to a draggable port on the canvas; not derived from underlying row observer and not applicable to row view models in the inspector
    @MainActor var portUIViewModel: OutputPortUIViewModel
    
    // Delegates, weak references to parents
    @MainActor weak var rowDelegate: OutputNodeRowObserver?
    
    /*
      Can an inspector output-row ever have a canvas item delegate ? Or would a "layer output on the graph" be represented as a non-nil canvas item reference on the `OutputLayerNodeRowData` ?
     */
    @MainActor weak var canvasItemDelegate: CanvasItemViewModel?
    
    init(id: NodeRowViewModelId,
         initialValue: PortValue,
         rowDelegate: OutputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        
        self.portUIViewModel = .init(id: OutputCoordinate(portId: id.portId,
                                                   nodeId: id.nodeId))
        self.id = id
        
        self.fieldsUIViewModel = .init(id: id,
                                       cachedActiveValue: initialValue,
                                       // TODO: just make fieldValueGroups here?
                                       cachedFieldValueGroups: .init())
        
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
