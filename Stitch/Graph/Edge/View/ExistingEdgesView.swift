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
    @Bindable var graphUI: GraphUIState
    let allInputs: NodeRowObservers
    
    var animatingEdges: PossibleEdgeSet {
        graphUI.edgeEditingState?.possibleEdges ?? .init()
    }
    
    var edgeAnimationEnabled: Bool {
        graphUI.edgeAnimationEnabled
    }
    
    var shownPossibleEdgeIds: Set<PossibleEdgeId> {
        graphUI.edgeEditingState?.shownIds ?? .init()
    }
    
    @MainActor
    func getPossibleEdgeUpstreamObserver(from input: NodeRowObserver,
                                         possibleEdge: PossibleEdge?) -> NodeRowObserver? {
        guard let possibleEdge = possibleEdge else {
            return nil
        }

        // Works, even after initial LayerInputOnGraph changes, becauses an edge's origin is still always a patch node output.
        // TODO: search for LayerOutputsOnGraph when we allow a LayerNode's outputs to be manually added to the canvas
        let node = graph.getNodeViewModel(possibleEdge.edge.from.nodeId)
        let upstreamRowObserver = node?.getOutputRowObserver(possibleEdge.edge.from.portId)
        return upstreamRowObserver
    }
    
    var body: some View {
        ForEach(allInputs) { inputObserver in
            
            let possibleEdge = animatingEdges.first(where: { $0.edge.to == inputObserver.portViewType?.input })
            
            let possibleEdgeOutputObserver = self.getPossibleEdgeUpstreamObserver(
                from: inputObserver,
                possibleEdge: possibleEdge)
            
            let upstreamObserver = inputObserver.upstreamOutputObserver
            
            ConnectedEdgeView(
                graph: graph,
                inputObserver: inputObserver,
                outputObserver: upstreamObserver,
                possibleEdgeOutputObserver: possibleEdgeOutputObserver,
                possibleEdge: possibleEdge,
                edgeAnimationEnabled: edgeAnimationEnabled,
                shownPossibleEdgeIds: shownPossibleEdgeIds)
        }
    }
}

extension ConnectedEdgeView {
    @MainActor
    init(graph: GraphState,
          inputObserver: NodeRowObserver,
          outputObserver: NodeRowObserver?,
          possibleEdgeOutputObserver: NodeRowObserver?,
          possibleEdge: PossibleEdge?,
          edgeAnimationEnabled: Bool,
         shownPossibleEdgeIds: Set<PossibleEdgeId>) {
        let downstreamNode = inputObserver.nodeDelegate
        // Needs to have at least a connected output or a "possible" output
        let outputObserverForData = outputObserver ?? possibleEdgeOutputObserver
        self.inputData = .init(from: inputObserver,
                               upstreamNodeId: outputObserverForData?.id.nodeId)
        self.outputData = .init(from: outputObserverForData,
                                connectedDownstreamNode: downstreamNode)
        
        self.graph = graph
        self.upstreamObserver = outputObserver
        self.inputObserver = inputObserver
        self.edgeAnimationEnabled = edgeAnimationEnabled
        self.possibleEdge = possibleEdge
        self.possibleEdgeOutputObserver = possibleEdgeOutputObserver
        self.shownPossibleEdgeIds = shownPossibleEdgeIds
    }
}

struct ConnectedEdgeView: View {

    @Environment(\.appTheme) private var theme
    @Environment(\.edgeStyle) private var edgeStyle

    let graph: GraphState
    
    // Optional in event we only have possible edge
    let upstreamObserver: NodeRowObserver?
    @Bindable var inputObserver: NodeRowObserver
    let inputData: EdgeAnchorDownstreamData?
    let outputData: EdgeAnchorUpstreamData?
    let edgeAnimationEnabled: Bool
    let possibleEdge: PossibleEdge?
    let possibleEdgeOutputObserver: NodeRowObserver?
    let shownPossibleEdgeIds: Set<PossibleEdgeId>
        
    var body: some View {
        let firstUpstreamObserver = inputData?.firstInputObserver
        let firstInputObserver = inputData?.firstInputObserver
        let lastInputObserver = inputData?.lastInputObserver
        let firstConnectedInputObserver = inputData?.firstConnectedInputObserver
        let lastConnectedInputObserver = inputData?.lastConectedInputObserver
        let lastUpstreamObserver = outputData?.lastUpstreamObserver
        let totalOutputs = outputData?.totalOutputs ?? 0
        let lastConnectedUpstreamObserver = outputData?.lastConnectedUpstreamObserver
        let pointTo = inputObserver.anchorPoint ?? .zero
        let edgeAnimationEnabled = edgeAnimationEnabled
        let possibleEdge = possibleEdge
        let possibleEdgeOutputObserver = possibleEdgeOutputObserver
        let shownPossibleEdgeIds = shownPossibleEdgeIds
        
        if let inputPortViewData = inputObserver.inputPortViewData,
           let upstreamObserver = upstreamObserver,
           let outputPortViewData = upstreamObserver.outputPortViewData {
            
            let edge = PortEdgeUI(from: outputPortViewData,
                                  to: inputPortViewData)
            
            let portColor: PortColor = inputObserver.portColor
            
            let isSelectedEdge = (portColor == .highlightedEdge || portColor == .highlightedLoopEdge)
            
            // Shouldn't we ALWAYS have a node delegate on the upstream observer?
            let upstreamObserverZIndex = upstreamObserver.nodeDelegate?.zIndex ?? 0
            
            let defaultInputNodeIndex = inputObserver.nodeDelegate?.zIndex ?? 0
            
            // If this input is a group input splitter, then we want to use the z-index of the group node on the same level as the edge, not the z-index of the group input splitter one level below.
            let zIndexOfInputNode = inputObserver.nodeDelegate?.parentGroupNodeId
                .flatMap({
                    parentId in graph.getNodeViewModel(parentId)?.zIndex
                }) ?? defaultInputNodeIndex
            
            
            let base = max(upstreamObserverZIndex, zIndexOfInputNode)
            
            let boost = isSelectedEdge ? SELECTED_EDGE_Z_INDEX_BOOST : 0
            
            let zIndex: ZIndex = base + boost
            
            EdgeView(edge: edge,
                     pointFrom: upstreamObserver.anchorPoint ?? .zero,
                     pointTo: pointTo,
                     color: portColor.color(theme),
                     isActivelyDragged: false,
                     firstFrom: firstUpstreamObserver?.anchorPoint ?? .zero,
                     firstTo: firstInputObserver?.anchorPoint ?? .zero,
                     lastFrom: lastUpstreamObserver?.anchorPoint ?? .zero,
                     lastTo: lastInputObserver?.anchorPoint ?? .zero,
                     firstFromWithEdge: firstConnectedInputObserver?.anchorPoint?.y ?? .zero,
                     lastFromWithEdge: lastConnectedUpstreamObserver?.anchorPoint?.y ?? .zero,
                     firstToWithEdge: firstConnectedInputObserver?.anchorPoint?.y ?? .zero,
                     lastToWithEdge: lastConnectedInputObserver?.anchorPoint?.y ?? .zero,
                     totalOutputs: totalOutputs,
                     edgeAnimationEnabled: edgeAnimationEnabled)
            .zIndex(zIndex)
            
        } else {
            EmptyView()
        }
            
        // Place possible-edges above existing edges
        if let possibleEdge = possibleEdge,
           let possibleEdgeOutputObserver = possibleEdgeOutputObserver {
            PossibleEdgeView(edgeStyle: edgeStyle,
                             possibleEdge: possibleEdge,
                             shownPossibleEdgeIds: shownPossibleEdgeIds,
                             from: possibleEdgeOutputObserver.anchorPoint ?? .zero,
                             to: pointTo,
                             totalOutputs: totalOutputs,
                             // Note: an animated edit-mode edge use its output's color, rather than input's color, since the input will be gray until animation is completed
                             color: possibleEdgeOutputObserver.portColor.color(theme))
        }
    }
}

// If we tap an edge specifically,
// then deselect all other edges and nodes,
// and select only that tapped edge.
struct EdgeTapped: GraphEvent {
    let edge: PortEdgeUI

    func handle(state: GraphState) {
        state.resetAlertAndSelectionState()
        state.selectedEdges = Set([edge])
    }
}

extension CGPoint {
    func rounded(toPlaces: Int) -> Self {
        .init(x: CGFloat(Double(self.x).rounded(toPlaces: toPlaces)),
              y: CGFloat(Double(self.y).rounded(toPlaces: toPlaces)))
    }
}
