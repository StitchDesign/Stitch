//
//  NodeRowObserverColorUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

extension PortColor {
    /*
     `isSelected: Bool`: Is the port "selected"? Depending on context, could mean that node is selected, OR edge is selected, OR edge is actively drawn but has eligible-input etc.
     
     `hasLoop: Bool`: Does the port have a loop?
     
     `hasEdge: Bool`: Does the port have an edge?
     */
    init(isSelected: Bool, hasEdge: Bool, hasLoop: Bool) {
        if hasLoop && hasEdge && isSelected {
            self = .highlightedLoopEdge
        } else if hasEdge && isSelected {
            self = .highlightedEdge
        } else if hasLoop && hasEdge {
            self = .loopEdge
        } else if hasEdge {
            self = .edge
        } else {
            self = .noEdge
        }
    }
}

extension NodeRowViewModel {
    // TODO: don't we have an abstract helper here for ANY property?
    // e.g. `self.portColor.setOnChange(newPortColor)`
    @MainActor
    func setPortColorIfChanged(_ newPortColor: PortColor) {
        if newPortColor != self.portColor {
            self.portColor = newPortColor
        }
    }
}

struct UpdatePortColorUponNodeSelected: GraphEvent {
    let nodeId: NodeId
    
    func handle(state: GraphState) {
        guard let node = state.getNode(nodeId) else {
            return
        }
        
        let selectedEdges = state.selectedEdges
        let drawingObserver = state.edgeDrawingObserver
        
        // TODO: should `updateObserversConnectedCanvasItems` also update the port color of connected (upstream output, downstream inputs) ? 
        node.updateObserversConnectedCanvasItems(
            selectedEdges: state.selectedEdges,
            drawingObserver: state.edgeDrawingObserver)
                        
        // update each output's downstream inputs
        node.outputsObservers.forEach { output in
            state.connections
                .get(output.id)?
                .compactMap { state.getInputRowObserver($0) }
                .forEach {
                    $0.updateConnectedCanvasItems(selectedEdges: selectedEdges,
                                                  drawingObserver: drawingObserver)
                }
        }
        
        // update each input's upstream output
        node.inputsObservers.forEach { input in
            if let output = input.upstreamOutputObserver {
                output.updateConnectedCanvasItems(selectedEdges: selectedEdges,
                                                  drawingObserver: drawingObserver)
            }
        }
    }
}
