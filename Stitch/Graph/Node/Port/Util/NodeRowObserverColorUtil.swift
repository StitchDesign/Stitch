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

struct UpdatePortColorUponNodeSelected: GraphEvent {
    let nodeId: NodeId
    
    func handle(state: GraphState) {
        state.getNode(nodeId)?.updateObserversPortColorsAndConnectedItemsPortColors(
            selectedEdges: state.selectedEdges,
            selectedCanvasItems: state.selection.selectedCanvasItems,
            drawingObserver: state.edgeDrawingObserver)
    }
}
