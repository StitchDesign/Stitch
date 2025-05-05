//
//  InputNodeRowViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation


@Observable
final class InputNodeRowViewModel: NodeRowViewModel {
        
    static let nodeIO: NodeIO = .input
    
    let id: NodeRowViewModelId
        
    // Cached ui-data derived from underlying row observer
    @MainActor var fieldsUIViewModel: RowFieldsUIViewModel
    
    // Data specific to a draggable port on the canvas; not derived from underlying row observer and not applicable to row view models in the inspector
    @MainActor var portUIViewModel: InputPortUIViewModel
    
    // Delegates, weak references to parents
    @MainActor weak var rowDelegate: InputNodeRowObserver?
    
    // TODO: input node row view model for an inspector should NEVER have canvasItemDelegate
    @MainActor weak var canvasItemDelegate: CanvasItemViewModel? // also nil when the layer input is not on the canvas
    
    @MainActor
    init(id: NodeRowViewModelId,
         initialValue: PortValue,
         rowDelegate: InputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.portUIViewModel = .init(id: InputCoordinate(portId: id.portId,
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

extension InputNodeRowObserver {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        // Does this input row observer has an upstream connection (i.e. output observer)?
        // If so, return that observer's canvas item id
        if let upstreamId = self.upstreamOutputObserver?.rowViewModelForCanvasItemAtThisTraversalLevel?.canvasItemDelegate?.id {
            return .init([upstreamId])
        } else {
            return .init()
        }
    }
}
