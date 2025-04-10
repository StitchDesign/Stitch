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
    func updatePortColorAndDepencies(selectedEdges: Set<PortEdgeUI>,
                                     drawingObserver: EdgeDrawingObserver) {
        self.allRowViewModels.forEach {
            // `Connected canvas items` are used by calculatePortColor to determine whether a port is 'selected' or not
            // Perhaps redundant, given that we now carefully control when we updatePortColor ?
            $0.connectedCanvasItems = $0.findConnectedCanvasItems(rowObserver: self)
            $0.updatePortColor(hasEdge: self.hasEdge,
                               hasLoop: self.hasLoopedValues,
                               selectedEdges: selectedEdges,
                               drawingObserver: drawingObserver)
        }
        
        // Update this input's upstream output's port color
        if let output = self.upstreamOutputObserver {
            output.updatePortColorAndDepencies(selectedEdges: selectedEdges,
                                              drawingObserver: drawingObserver)
        }
        
    }
}

extension OutputNodeRowObserver {
    @MainActor
    func updatePortColorAndDepencies(selectedEdges: Set<PortEdgeUI>,
                                     drawingObserver: EdgeDrawingObserver) {
        
        self.allRowViewModels.forEach {
            $0.connectedCanvasItems = $0.findConnectedCanvasItems(rowObserver: self)
            $0.updatePortColor(hasEdge: self.hasEdge,
                               hasLoop: self.hasLoopedValues,
                               selectedEdges: selectedEdges,
                               drawingObserver: drawingObserver)
        }
        
        // Update this output's downstream inputs' port colors
        // TODO: this triggers infinite recursion, since InputRowObserver also calls OutputRowObserver.updateConnectedCanvasItems
//        self.getDownstreamInputsObservers().forEach { (inputObserver: InputNodeRowObserver) in
//            inputObserver.updateConnectedCanvasItems(selectedEdges: selectedEdges,
//                                                     drawingObserver: drawingObserver)
//        }

        // TODO: the input observer is connected to this output observer, so why can't I use outputObserver.hasEdge etc.? Why must I retrieve the downstream input's observer? Does this indicate something is out of sync?
        self.getConnectedDownstreamNodes().forEach { (canvas: CanvasItemViewModel) in
            canvas.inputViewModels.forEach { (inputRowViewModel: InputNodeRowViewModel) in
                if let inputObserver = inputRowViewModel.rowDelegate {
                    inputRowViewModel.updatePortColor(hasEdge: inputObserver.hasEdge,
                                                      hasLoop: inputObserver.hasLoopedValues,
                                                      selectedEdges: selectedEdges,
                                                      drawingObserver: drawingObserver)
                }
            }
        }
        
    }
}
