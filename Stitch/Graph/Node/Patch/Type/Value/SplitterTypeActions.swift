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
struct SplitterTypeChanged: GraphEvent {

    let newType: SplitterType
    let currentType: SplitterType
    let splitterNodeId: NodeId

    func handle(state: GraphState) {
        //        log("SplitterOptionSelected called: newType: \(newType)")
        //        log("SplitterOptionSelected called: currentType: \(currentType)")

        guard let activeGroupId = state.graphUI.groupNodeFocused else {
            log("SplitterOptionSelected: no active group")
            return
        }

        guard let splitterNode = state.getNodeViewModel(splitterNodeId) else {
            log("SplitterOptionSelected: could not find GroupNode \(activeGroupId)")
            return
        }

        state.setSplitterType(
            splitterNode: splitterNode,
            newType: newType,
            currentType: currentType)
        
        // Forces group port view models to update
        state.updateGraphData()

        // Recalculate the graph, since we may have flattened an input on a splitter node and so that output should be flat as well (happens via node eval).
        state.calculateFullGraph()
        
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    @MainActor
    func setSplitterType(splitterNode: NodeViewModel,
                         newType: SplitterType,
                         currentType: SplitterType) {

        let outputPort = NodeIOCoordinate(portId: 0, nodeId: splitterNode.id)

        // Set type to view model
        splitterNode.splitterType = newType

        switch newType {
        case .inline:
            // If we switched away from being an output- or input-splitter,
            // we need to remove some edges.
            if currentType == .output {
                self.removeConnections(from: outputPort,
                                       isNodeVisible: splitterNode.isVisibleInFrame)
            } else if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver
                        .removeUpstreamConnection(activeIndex: self.activeIndex,
                                                  isVisible: splitterNode.isVisibleInFrame)
                }
            }

        case .input:
            // If we switched away from being an output-splitter,
            // then need to remove outgoing edges.
            if currentType == .output {
                self.removeConnections(from: outputPort,
                                       isNodeVisible: splitterNode.isVisibleInFrame)
            }

        case .output:
            // If we switched away from being an input-splitter,
            // then need to remove the incoming edge.
            if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver
                        .removeUpstreamConnection(activeIndex: self.activeIndex,
                                                  isVisible: splitterNode.isVisibleInFrame)
                }
            }
        }
    }
}
