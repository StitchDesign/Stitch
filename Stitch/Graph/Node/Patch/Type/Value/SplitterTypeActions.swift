//
//  SplitterTypeActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/22/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// formerly `SplitterOptionSelected`
struct SplitterTypeChanged: StitchDocumentEvent {

    let newType: SplitterType
    let currentType: SplitterType
    let splitterNodeId: NodeId

    func handle(state: StitchDocumentViewModel) {
        //        log("SplitterOptionSelected called: newType: \(newType)")
        //        log("SplitterOptionSelected called: currentType: \(currentType)")

        let graph = state.visibleGraph
        
        guard let activeGroupId = state.groupNodeFocused else {
            log("SplitterOptionSelected: no active group")
            return
        }

        guard let splitterNode = graph.getNodeViewModel(splitterNodeId) else {
            log("SplitterOptionSelected: could not find GroupNode \(activeGroupId)")
            return
        }

        graph.setSplitterType(
            splitterNode: splitterNode,
            newType: newType,
            currentType: currentType,
            activeIndex: state.activeIndex)
        
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
                self.removeConnections(from: outputPort,
                                       isNodeVisible: splitterNode.isVisibleInFrame(self.visibleCanvasIds, self.selectedSidebarLayers))
            } else if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver
                        .removeUpstreamConnection(isVisible: splitterNode.isVisibleInFrame(self.visibleCanvasIds, self.selectedSidebarLayers),
                                                  node: splitterNode)
                }
            }

        case .input:
            // If we switched away from being an output-splitter,
            // then need to remove outgoing edges.
            if currentType == .output {
                self.removeConnections(from: outputPort,
                                       isNodeVisible: splitterNode.isVisibleInFrame(self.visibleCanvasIds, self.selectedSidebarLayers))
            }

        case .output:
            // If we switched away from being an input-splitter,
            // then need to remove the incoming edge.
            if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver
                        .removeUpstreamConnection(isVisible: splitterNode.isVisibleInFrame(self.visibleCanvasIds, self.selectedSidebarLayers),
                                                  node: splitterNode)
                }
            }
        }
        
        // Resize group node given new fields
        if let groupNodeId = splitterNode.patchCanvasItem?.parentGroupNodeId,
           let groupCanvasNode = self.getNodeViewModel(groupNodeId)?.patchCanvasItem {
            groupCanvasNode.resetViewSizingCache()
        }
    }
}
