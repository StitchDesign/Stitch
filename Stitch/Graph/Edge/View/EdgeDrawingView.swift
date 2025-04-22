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
//    let inputsAtThisTraversalLevel: [InputNodeRowViewModel]
    
    var body: some View {
        if let outputDrag = edgeDrawingObserver.drawingGesture {
            EdgeFromDraggedOutputView(
                graph: graph,
                outputDrag: outputDrag,
                nearestEligibleInput: edgeDrawingObserver.nearestEligibleInput)
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

    var outputRowViewModel: OutputNodeRowViewModel {
        outputDrag.output
    }
    
    // Note: the rules for the color of an actively dragged edge are simple:
    // gray if no eligible input, else highlighted-loop if a loop, else highlighted.
    @MainActor
    var color: PortColor {
        if !nearestEligibleInput.isDefined {
            return .noEdge
        } else if (outputRowViewModel.rowDelegate?.hasLoopedValues ?? false) {
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
            if let downstreamNode = outputDrag.output.nodeDelegate,
               let upstreamCanvasItem = outputRowViewModel.canvasItemDelegate,
                let outputAnchorData = EdgeAnchorUpstreamData(
                    from: upstreamCanvasItem.outputPortUIViewModels,
                    upstreamNodeId: upstreamCanvasItem.id.nodeId,
                    inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels),
               let outputPortViewData = outputRowViewModel.portAddress,
               let outputNodeId = outputRowViewModel.canvasItemDelegate?.id,
               let pointFrom = outputRowViewModel.portUIViewModel.anchorPoint {
                let edge = PortEdgeUI(from: outputPortViewData,
                                      to: .init(portId: -1,
                                                canvasId: outputNodeId))
                
                EdgeView(edge: edge,
                         pointFrom: pointFrom,
                         pointTo: pointTo,
                         color: self.color.color(theme),
                         isActivelyDragged: true, // always true for actively-dragged edge
                         firstFrom: outputAnchorData.firstUpstreamOutput.anchorPoint ?? .zero,
                         firstTo: inputAnchorData?.firstInput.anchorPoint ?? .zero,
                         lastFrom: outputAnchorData.lastUpstreamRowOutput.anchorPoint ?? .zero,
                         lastTo: inputAnchorData?.lastInput.anchorPoint ?? .zero,
                         firstFromWithEdge: outputAnchorData.firstConnectedUpstreamOutput?.anchorPoint?.y,
                         lastFromWithEdge: outputAnchorData.lastConnectedUpstreamOutput?.anchorPoint?.y,
                         firstToWithEdge: inputAnchorData?.firstConnectedInput.anchorPoint?.y,
                         lastToWithEdge: inputAnchorData?.lastConectedInput.anchorPoint?.y,
                         totalOutputs: outputAnchorData.totalOutputs,
                         // we never animate the actively dragged edge
                         edgeAnimationEnabled: false)
                .animation(.default, value: color)
            }
        }
        .onChange(of: pointTo) {
            if let outputNodeId = outputRowViewModel.canvasItemDelegate?.id {
                graph.findEligibleInput(
                    cursorLocation: pointTo,
                    cursorNodeId: outputNodeId)
            }
        }
    }
}
