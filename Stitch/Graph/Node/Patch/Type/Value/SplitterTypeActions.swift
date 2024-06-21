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
struct SplitterTypeChanged: ProjectEnvironmentEvent {

    let newType: SplitterType
    let currentType: SplitterType
    let splitterNodeId: NodeId

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        //        log("SplitterOptionSelected called: newType: \(newType)")
        //        log("SplitterOptionSelected called: currentType: \(currentType)")

        guard let activeGroupId = graphState.graphUI.groupNodeFocused else {
            log("SplitterOptionSelected: no active group")
            return .noChange
        }

        guard let splitterNode = graphState.getNodeViewModel(splitterNodeId) else {
            log("SplitterOptionSelected: could not find GroupNode \(activeGroupId)")
            return .noChange
        }

        graphState.setSplitterType(
            splitterNode: splitterNode,
            newType: newType,
            currentType: currentType)

        // Recalculate the graph, since we may have flattened an input on a splitter node and so that output should be flat as well (happens via node eval).
        graphState.calculateFullGraph()
        
        return .init(willPersist: true)
    }
}

extension GraphState {
    @MainActor
    func setSplitterType(splitterNode: NodeViewModel,
                         newType: SplitterType,
                         currentType: SplitterType) {

        guard let canvasItem = splitterNode.canvasUIData else {
            fatalErrorIfDebug()
            return
        }
        
        let outputPort = NodeIOCoordinate(portId: 0, nodeId: splitterNode.id)

        // Set type to view model
        splitterNode.splitterType = newType

        switch newType {
        case .inline:
            // If we switched away from being an output- or input-splitter,
            // we need to remove some edges.
            if currentType == .output {
                self.removeConnections(from: outputPort,
                                       isNodeVisible: canvasItem.isVisibleInFrame)
            } else if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver
                        .removeUpstreamConnection(activeIndex: self.activeIndex,
                                                  isVisible: canvasItem.isVisibleInFrame)
                }
            }

        case .input:
            // If we switched away from being an output-splitter,
            // then need to remove outgoing edges.
            if currentType == .output {
                self.removeConnections(from: outputPort,
                                       isNodeVisible: canvasItem.isVisibleInFrame)
            }

        case .output:
            // If we switched away from being an input-splitter,
            // then need to remove the incoming edge.
            if currentType == .input {
                if let inputObserver = splitterNode.getInputRowObserver(for: .portIndex(0)) {
                    inputObserver
                        .removeUpstreamConnection(activeIndex: self.activeIndex,
                                                  isVisible: canvasItem.isVisibleInFrame)
                }
            }
        }
    }
}
