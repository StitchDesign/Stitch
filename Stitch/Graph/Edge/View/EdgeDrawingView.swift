//
//  EdgeDrawingView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

struct EdgeDrawingView: View {
    let graph: GraphState
    @Bindable var edgeDrawingObserver: EdgeDrawingObserver
    let inputsAtThisTraversalLevel: [InputNodeRowViewModel]
    
    var body: some View {
        if let outputDrag = edgeDrawingObserver.drawingGesture {
            EdgeFromDraggedOutputView(
                graph: graph,
                outputDrag: outputDrag,
                nearestEligibleInput: edgeDrawingObserver.nearestEligibleInput,
                eligibleInputCandidates: inputsAtThisTraversalLevel)
        } else {
            EmptyView()
        }
    }
}

struct EdgeFromDraggedOutputView: View {
    
    @Environment(\.appTheme) var theme
    let graph: GraphState
    
    // ie cursor position
    let outputDrag: OutputDragGesture
    let nearestEligibleInput: InputNodeRowViewModel?
    let eligibleInputCandidates: [InputNodeRowViewModel]

    var outputRowViewModel: OutputNodeRowViewModel {
        outputDrag.output
    }
    
    // Note: the rules for the color of an actively dragged edge are simple: highlighted-loop if a loop, else highlighted.
    @MainActor
    var color: PortColor {
        guard nearestEligibleInput.isDefined else {
            // Actively dragged edges are always gray if there is no eligible input yet
            return .noEdge
        }
        
        if outputRowViewModel.rowDelegate?.hasLoopedValues ?? false {
            return .highlightedLoopEdge
        } else {
            return .highlightedEdge
        }
    }

    var pointTo: CGPoint {
        outputDrag.dragLocation
    }
    
    @MainActor
    var inputAnchorData: EdgeAnchorDownstreamData? {
        guard let nearestEligibleInput = nearestEligibleInput else {
            return nil
        }
        return EdgeAnchorDownstreamData(from: nearestEligibleInput)
    }
    
    var body: some View {
        Group {
            if let outputAnchorData = EdgeAnchorUpstreamData(from: outputRowViewModel,
                                                             connectedDownstreamNode: nearestEligibleInput?.nodeDelegate),
               let outputPortViewData = outputRowViewModel.portViewData,
               let pointFrom = outputRowViewModel.anchorPoint,
               let outputNodeId = outputRowViewModel.canvasItemDelegate?.id {
                let edge = PortEdgeUI(from: outputPortViewData,
                                      to: .init(portId: -1,
                                                canvasId: outputNodeId))
                
                EdgeView(edge: edge,
                         pointFrom: pointFrom,
                         pointTo: pointTo,
                         color: self.color.color(theme),
                         isActivelyDragged: true, // always true for actively-dragged edge
                         firstFrom: outputAnchorData.firstUpstreamObserver.anchorPoint ?? .zero,
                         firstTo: inputAnchorData?.firstInputObserver.anchorPoint ?? .zero,
                         lastFrom: outputAnchorData.lastUpstreamObserver.anchorPoint ?? .zero,
                         lastTo: inputAnchorData?.lastInputObserver.anchorPoint ?? .zero,
                         firstFromWithEdge: outputAnchorData.firstConnectedUpstreamObserver?.anchorPoint?.y,
                         lastFromWithEdge: outputAnchorData.lastConnectedUpstreamObserver?.anchorPoint?.y,
                         firstToWithEdge: inputAnchorData?.firstConnectedInputObserver?.anchorPoint?.y,
                         lastToWithEdge: inputAnchorData?.lastConectedInputObserver?.anchorPoint?.y,
                         totalOutputs: outputAnchorData.totalOutputs,
                         // we never animate the actively dragged edge
                         edgeAnimationEnabled: false)
                .animation(.default, value: color)
                .onChange(of: pointTo) {
                    graph.findEligibleInput(
                        cursorLocation: pointTo,
                        cursorNodeId: outputNodeId,
                        eligibleInputCandidates: eligibleInputCandidates)
                }
            }
        }
    }
}
