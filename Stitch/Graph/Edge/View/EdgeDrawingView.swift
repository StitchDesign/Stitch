//
//  EdgeDrawingView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

struct EdgeDrawingView: View {
    @Bindable var edgeDrawingObserver: EdgeDrawingObserver
    let inputsAtThisTraversalLevel: NodeRowObservers
    
    var body: some View {
        if let outputDrag = edgeDrawingObserver.drawingGesture {
            EdgeFromDraggedOutputView(
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
    
    // ie cursor position
    let outputDrag: OutputDragGesture
    let nearestEligibleInput: NodeRowObserver? //InputPortViewData?
    let eligibleInputCandidates: NodeRowObservers

    var outputRowObserver: NodeRowObserver {
        outputDrag.output
    }
    
    // Note: the rules for the color of an actively dragged edge are simple: highlighted-loop if a loop, else highlighted.
    @MainActor
    var color: PortColor {
        guard nearestEligibleInput.isDefined else {
            // Actively dragged edges are always gray if there is no eligible input yet
            return .noEdge
        }
        
        if outputRowObserver.hasLoopedValues {
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
            if let outputAnchorData = EdgeAnchorUpstreamData(from: outputRowObserver,
                                                             connectedDownstreamNode: nearestEligibleInput?.nodeDelegate),
               let outputPortViewData = outputRowObserver.outputPortViewData,
                let pointFrom = outputRowObserver.anchorPoint {               
                let edge = PortEdgeUI(from: outputPortViewData,
                                      to: .init(portId: -1, nodeId: .init()))
                
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
            }
        }
        .onChange(of: pointTo) {
            findEligibleInput(
                cursorLocation: pointTo,
                cursorNodeId: outputDrag.output.id.nodeId,
                eligibleInputCandidates: eligibleInputCandidates)
        }
    }
}
