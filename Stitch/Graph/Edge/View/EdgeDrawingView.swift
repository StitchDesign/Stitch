//
//  EdgeDrawingView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

struct EdgeFromDraggedOutputView: View {
    
    @Environment(\.appTheme) var theme
    @Bindable var graph: GraphState
    
    // Technically either a dragged output OR a dragged input?
    // i.e. cursor position
    let outputDrag: OutputDragGesture
    
    let nearestEligibleInput: InputNodeRowViewModel?

    let outputRowViewModel: OutputNodeRowViewModel
    let canvasItem: CanvasItemViewModel
    
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
        outputDrag.cursorLocationInGlobalCoordinateSpace
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
            if let downstreamNode = graph.getNode(outputDrag.outputId.nodeId),
               let upstreamCanvasItem = outputRowViewModel.canvasItemDelegate,
                let outputAnchorData = EdgeAnchorUpstreamData(
                    from: upstreamCanvasItem.outputPortUIViewModels,
                    upstreamNodeId: upstreamCanvasItem.id.nodeId,
                    inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels),
               let outputPortAddress = outputRowViewModel.portUIViewModel.portAddress,
               let outputNodeId = outputRowViewModel.canvasItemDelegate?.id,
               let pointFrom = outputRowViewModel.portUIViewModel.anchorPoint {
                
                logInView("EdgeFromDraggedOutputView: pointFrom: \(pointFrom)")
                logInView("EdgeFromDraggedOutputView: pointTo: \(pointTo)")
                
                let edge = PortEdgeUI(from: outputPortAddress,
                                      to: .init(portId: -1, // Nonsense
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
                         edgeAnimationEnabled: false,
                         edgeScaleEffect: .nonEdgeToInspectorScaleEffect)
                .animation(.linear(duration: DrawnEdge.ANIMATION_DURATION),
                           value: color)
            }
        }
        .onChange(of: pointTo) {
            if let outputNodeId = outputRowViewModel.canvasItemDelegate?.id {
                graph.findEligibleCanvasInput(
                    cursorLocation: pointTo,
                    cursorNodeId: outputNodeId)
            }
        }
    }
}

extension CGFloat {
    // For edges that are rendered within the UIScrollView,
    // we always use scale = 1,
    // since the UIScrollView itself will
    // Only varies for those edges that can be drawn into the inspector.
    static let nonEdgeToInspectorScaleEffect: Self = 1
}
