//
//  SplitterTypeActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/22/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit


struct SplitterTypeChangedFromCanvasItemMenu: StitchDocumentEvent {

    let newType: SplitterType

    func handle(state: StitchDocumentViewModel) {

        guard state.groupNodeFocused.isDefined else {
            log("SplitterTypeChangedFromCanvasItemMenu: no active group")
            return
        }
                
        let graph = state.visibleGraph
        
        graph.selectedCanvasItems.forEach { canvasItemId in
            if let splitter = graph.getNode(id: canvasItemId.nodeId),
               let currentType = splitter.splitterType {
                
                graph.setSplitterType(
                    splitterNode: splitter,
                    newType: newType,
                    currentType: currentType,
                    activeIndex: state.activeIndex)
            }
        }
        
        // Forces group port view models to update
        graph.updateGraphData(state)

        // Recalculate the graph, since we may have flattened an input on a splitter node and so that output should be flat as well (happens via node eval).
        graph.calculateFullGraph()
        
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    @MainActor
    func setSplitterType(splitterNode: NodeViewModel,
                         newType: SplitterType,
                         currentType: SplitterType,
                         activeIndex: ActiveIndex) {

        let outputPort = NodeIOCoordinate(portId: 0, nodeId: splitterNode.id)

        // Set type to view model
        splitterNode.splitterType = newType

        switch newType {
        case .inline:
            // If we switched away from being an output- or input-splitter,
            // we need to remove some edges.
            if currentType == .output {
                self.removeConnections(from: outputPort)
            } else if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver.removeUpstreamConnection(node: splitterNode)
                }
            }

        case .input:
            // If we switched away from being an output-splitter,
            // then need to remove outgoing edges.
            if currentType == .output {
                self.removeConnections(from: outputPort)
            }

        case .output:
            // If we switched away from being an input-splitter,
            // then need to remove the incoming edge.
            if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver.removeUpstreamConnection(node: splitterNode)
                }
            }
            
            // Also, if we became an output, we need to remove any outgoing edges;
            // otherwise "input splitter -> output splitter" change will mean
            // that a group node's incoming edge is now... a group node output that feeds into the group itself !
            self.removeConnections(from: outputPort)
        }
        
        // Resize group node given new fields
        if let groupNodeId = splitterNode.nonLayerCanvasItem?.parentGroupNodeId,
           let groupCanvasNode = self.getNodeViewModel(groupNodeId)?.nonLayerCanvasItem {
            groupCanvasNode.resetViewSizingCache()
        }
    }
}
