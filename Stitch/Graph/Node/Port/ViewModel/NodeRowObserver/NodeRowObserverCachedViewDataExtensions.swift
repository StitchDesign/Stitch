//
//  NodeRowObserverCachedViewDataExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: derived/cached data: PortViewData, ActiveValue, PortColor

/*
 Iterates through this row observer's row view models, updating each row view model's:
 - cache of connectedCanvasItems
 - port color
 */
extension InputNodeRowObserver {
    
    @MainActor
    func refreshConnectedCanvasItemsCache() {
        self.allRowViewModels.forEach {
            $0.connectedCanvasItems = $0.findConnectedCanvasItems(rowObserver: self)
        }
    }
    
    @MainActor
    func updatePortColorAndUpstreamOutputPortColor(selectedEdges: Set<PortEdgeUI>,
                                                   drawingObserver: EdgeDrawingObserver) {
        self.allRowViewModels.forEach {
            $0.updatePortColor(hasEdge: self.hasEdge,
                               hasLoop: self.hasLoopedValues,
                               selectedEdges: selectedEdges,
                               drawingObserver: drawingObserver)
        }
        
        // Note: previously this was only done when node-tapped
        // Update this input's upstream-output's port color
        self.upstreamOutputObserver?.updateRowViewModelsPortColor(selectedEdges: selectedEdges,
                                                                  drawingObserver: drawingObserver)
    }
}

extension NodeRowObserver {
    @MainActor
    func updateRowViewModelsPortColor(selectedEdges: Set<PortEdgeUI>,
                                      drawingObserver: EdgeDrawingObserver) {
        self.allRowViewModels.forEach {
            $0.updatePortColor(hasEdge: self.hasEdge,
                               hasLoop: self.hasLoopedValues,
                               selectedEdges: selectedEdges,
                               drawingObserver: drawingObserver)
        }
    }
}

extension OutputNodeRowObserver {
    
    @MainActor
    func refreshConnectedCanvasItemsCache() {
        self.allRowViewModels.forEach {
            $0.connectedCanvasItems = $0.findConnectedCanvasItems(rowObserver: self)
        }
    }
    
    @MainActor
    func updatePortColorAndDownstreamInputsPortColors(selectedEdges: Set<PortEdgeUI>,
                                                      drawingObserver: EdgeDrawingObserver) {
        self.updateRowViewModelsPortColor(selectedEdges: selectedEdges,
                                          drawingObserver: drawingObserver)
        
        // Note: previously this was only done when node-tapped
        // Update this output's downstream inputs' port colors
        self.getDownstreamInputsObservers().forEach { (inputObserver: InputNodeRowObserver) in
            // TODO: the input observer is connected to this output observer, so why can't I use outputObserver.hasEdge etc.? Why must I retrieve the downstream input's observer? Does this indicate something is out of sync?
            inputObserver.updateRowViewModelsPortColor(selectedEdges: selectedEdges,
                                                       drawingObserver: drawingObserver)
        }
    }
}
