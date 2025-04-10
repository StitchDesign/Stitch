//
//  NodeRowObserverCachedViewDataExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: derived/cached data: PortViewData, ActiveValue, PortColor

// TODO: make these two `updateConnectedNodes` methods into a single method on NodeRowObserver ?
// Note that finding connected nodes for an input vs output is a little different?
extension InputNodeRowObserver {
    @MainActor
    func updateConnectedCanvasItems(selectedEdges: Set<PortEdgeUI>,
                                    drawingObserver: EdgeDrawingObserver) {
        self.allRowViewModels.forEach { rowViewModel in
            // `Connected canvas items` are used by calculatePortColor to determine whether a port is 'selected' or not
            // Perhaps redundant, given that we now carefully control when we updatePortColor ?
            rowViewModel.connectedCanvasItems = rowViewModel.findConnectedCanvasItems(rowObserver: self)
            rowViewModel.updatePortColor(hasEdge: self.hasEdge,
                                         hasLoop: self.hasLoopedValues,
                                         selectedEdges: selectedEdges,
                                         drawingObserver: drawingObserver)
        }
    }
}

extension OutputNodeRowObserver {
    @MainActor
    func updateConnectedCanvasItems(selectedEdges: Set<PortEdgeUI>,
                                    drawingObserver: EdgeDrawingObserver) {
        self.allRowViewModels.forEach { rowViewModel in
            rowViewModel.connectedCanvasItems = rowViewModel.findConnectedCanvasItems(rowObserver: self)
            rowViewModel.updatePortColor(hasEdge: self.hasEdge,
                                         hasLoop: self.hasLoopedValues,
                                         selectedEdges: selectedEdges,
                                         drawingObserver: drawingObserver)
        }
    }
}
