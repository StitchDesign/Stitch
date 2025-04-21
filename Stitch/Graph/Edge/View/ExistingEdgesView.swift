//
//  ExistingEdgesView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/27/23.
//

import SwiftUI
import StitchSchemaKit

struct GraphConnectedEdgesView: View {
    @Bindable var graph: GraphState

    var edgeAnimationEnabled: Bool {
        graph.edgeAnimationEnabled
    }
    
    // Identifies if some edge data contains "possible" edges, used during keyboard shortcut
    func isEdgeAnimating(_ edgeData: ConnectedEdgeData) -> Bool {
       let possibleEdge = graph.edgeEditingState?
            .possibleEdges
            .first(where: {
                $0.edge.to == edgeData.downstreamRowObserver.portAddress
                && graph.edgeEditingState?.animationInProgressIds.contains($0.id) ?? false
            })
        
        return possibleEdge.isDefined
    }
    
    var body: some View {
        ForEach(graph.connectedEdges) { (edgeData: ConnectedEdgeData) in
            // Filter out animated edges enables keyboard shortcut animation
            if !self.isEdgeAnimating(edgeData) {
                ConnectedEdgeView(data: edgeData,
                                  edgeAnimationEnabled: edgeAnimationEnabled)
            }
        }
    }
}

struct CandidateEdgesView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.edgeStyle) private var edgeStyle
    
    @Bindable var graph: GraphState
    
    var animatingEdges: [PossibleEdge] {
        guard let set = graph.edgeEditingState?.possibleEdges else {
            return []
        }
        
        return Array(set)
    }
    
    var edgeAnimationEnabled: Bool {
        graph.edgeAnimationEnabled
    }
    
    var shownPossibleEdgeIds: Set<PossibleEdgeId> {
        graph.edgeEditingState?.shownIds ?? .init()
    }
    
    @MainActor
    func getPossibleEdgeUpstreamObserver(possibleEdge: PossibleEdge) -> OutputNodeRowViewModel? {
        guard let node = graph.getCanvasItem(possibleEdge.edge.from.canvasId),
              let upstreamRowObserver = node.outputViewModels[safe: possibleEdge.edge.from.portId] else {
            return nil
        }

        return upstreamRowObserver
    }
    
    @MainActor
    func getPossibleEdgeDownstreamObserver(possibleEdge: PossibleEdge) -> InputNodeRowViewModel? {
        guard let node = graph.getCanvasItem(possibleEdge.edge.to.canvasId),
              let downstreamRowObserver = node.inputViewModels[safe: possibleEdge.edge.to.portId] else {
            return nil
        }

        return downstreamRowObserver
    }
    
    var body: some View {
        // Place possible-edges above existing edges
        Group {
            ForEach(animatingEdges) { possibleEdge in
                if let outputObserver = self
                    .getPossibleEdgeUpstreamObserver(possibleEdge: possibleEdge),
                   let inputObserver = self
                    .getPossibleEdgeDownstreamObserver(possibleEdge: possibleEdge),
                   let outputsCount = outputObserver.canvasItemDelegate?.outputViewModels.count {
                    let pointTo = inputObserver.anchorPoint ?? .zero
                    
                    PossibleEdgeView(edgeStyle: edgeStyle,
                                     possibleEdge: possibleEdge,
                                     shownPossibleEdgeIds: shownPossibleEdgeIds,
                                     from: outputObserver.anchorPoint ?? .zero,
                                     to: pointTo,
                                     totalOutputs: outputsCount,
                                     // Note: an animated edit-mode edge use its output's color, rather than input's color, since the input will be gray until animation is completed
                                     color: outputObserver.portColor.color(theme))
                }
            }
        }
    }
}

extension ConnectedEdgeView {
    @MainActor init(data: ConnectedEdgeData,
                    edgeAnimationEnabled: Bool) {
        self.inputRowViewModel = data.downstreamRowObserver
        self.upstreamOutputRowViewModel = data.upstreamRowObserver
        self.inputData = data.inputData
        self.outputData = data.outputData
        self.zIndex = data.zIndex
        self.edgeAnimationEnabled = edgeAnimationEnabled
    }
}

struct ConnectedEdgeView: View {

    @Environment(\.appTheme) private var theme
    
    @Bindable var inputRowViewModel: InputNodeRowViewModel
    @Bindable var upstreamOutputRowViewModel: OutputNodeRowViewModel
    let inputData: EdgeAnchorDownstreamData
    let outputData: EdgeAnchorUpstreamData
    let edgeAnimationEnabled: Bool
    let zIndex: Double
        
    var body: some View {
        let firstUpstreamObserver = inputData.firstInputRowViewModel
        let firstInputObserver = inputData.firstInputRowViewModel
        let lastInputObserver = inputData.lastInputRowViewModel
        let firstConnectedInputObserver = inputData.firstConnectedInputRowViewModel
        let lastConnectedInputObserver = inputData.lastConectedInputRowViewModel
        let lastUpstreamObserver = outputData.lastUpstreamRowViewModel
        let totalOutputs = outputData.totalOutputs
        let lastConnectedUpstreamObserver = outputData.lastConnectedUpstreamRowViewModel
        
        if let inputPortViewData = inputRowViewModel.portAddress,
           let outputPortViewData = upstreamOutputRowViewModel.portAddress,
           let pointTo = inputRowViewModel.anchorPoint,
           let pointFrom = upstreamOutputRowViewModel.anchorPoint,
           let firstFrom = firstUpstreamObserver.anchorPoint,
           let firstTo = firstInputObserver.anchorPoint,
           let lastFrom = lastUpstreamObserver.anchorPoint,
           let lastTo = lastInputObserver.anchorPoint,
           let firstFromWithEdge = firstConnectedInputObserver.anchorPoint?.y,
           let lastFromWithEdge = lastConnectedUpstreamObserver?.anchorPoint?.y,
           let firstToWithEdge = firstConnectedInputObserver.anchorPoint?.y,
           let lastToWithEdge = lastConnectedInputObserver.anchorPoint?.y {
            let edge = PortEdgeUI(from: outputPortViewData,
                                  to: inputPortViewData)
            let portColor: PortColor = inputRowViewModel.portColor
            let isSelectedEdge = (portColor == .highlightedEdge || portColor == .highlightedLoopEdge)
           
            let zIndexBoost = isSelectedEdge ? SELECTED_EDGE_Z_INDEX_BOOST : 0
            let newZIndex: ZIndex = self.zIndex + zIndexBoost
            
            EdgeView(edge: edge,
                     pointFrom: pointFrom,
                     pointTo: pointTo,
                     color: portColor.color(theme),
                     isActivelyDragged: false,
                     firstFrom: firstFrom,
                     firstTo: firstTo,
                     lastFrom: lastFrom,
                     lastTo: lastTo,
                     firstFromWithEdge: firstFromWithEdge,
                     lastFromWithEdge: lastFromWithEdge,
                     firstToWithEdge: firstToWithEdge,
                     lastToWithEdge: lastToWithEdge,
                     totalOutputs: totalOutputs,
                     edgeAnimationEnabled: edgeAnimationEnabled)
            .zIndex(newZIndex)
            
        } else {
            Color.clear
        }
    }
}

// If we tap an edge specifically,
// then deselect all other edges and nodes,
// and select only that tapped edge.
struct EdgeTapped: StitchDocumentEvent {
    let edge: PortEdgeUI

    func handle(state: StitchDocumentViewModel) {
        let graph = state.visibleGraph
        graph.resetAlertAndSelectionState(document: state)
        graph.selectedEdges = Set([edge])
    }
}

extension CGPoint {
    func rounded(toPlaces: Int) -> Self {
        .init(x: CGFloat(Double(self.x).rounded(toPlaces: toPlaces)),
              y: CGFloat(Double(self.y).rounded(toPlaces: toPlaces)))
    }
}
