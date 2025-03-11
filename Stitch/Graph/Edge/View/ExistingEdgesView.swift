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
//    let allConnectedInputs: [InputNodeRowViewModel]
    
    var animatingEdges: PossibleEdgeSet {
        graph.edgeEditingState?.possibleEdges ?? .init()
    }
    
    var edgeAnimationEnabled: Bool {
        graph.edgeAnimationEnabled
    }
    
    var shownPossibleEdgeIds: Set<PossibleEdgeId> {
        graph.edgeEditingState?.shownIds ?? .init()
    }
    
    @MainActor
    func getPossibleEdgeUpstreamObserver(from input: InputNodeRowViewModel,
                                         possibleEdge: PossibleEdge?) -> OutputNodeRowViewModel? {
        guard let possibleEdge = possibleEdge,
              let node = graph.getCanvasItem(possibleEdge.edge.from.canvasId),
              let upstreamRowObserver = node.outputViewModels[safe: possibleEdge.edge.from.portId] else {
            return nil
        }

        return upstreamRowObserver
    }
    
    var body: some View {
        ForEach(graph.connectedEdges) { edgeData in
            // Bindable fixes issue where edges may not appear initially
//            @Bindable var inputObserver = inputObserver
            
//            let possibleEdge = animatingEdges.first(where: { $0.edge.to == inputObserver.portViewData })
            
//            let possibleEdgeOutputObserver = self.getPossibleEdgeUpstreamObserver(
//                from: inputObserver,
//                possibleEdge: possibleEdge)
            
            ConnectedEdgeView(data: edgeData,
                              edgeAnimationEnabled: edgeAnimationEnabled)
            
        }
    }
}

extension ConnectedEdgeView {
    @MainActor init(data: ConnectedEdgeData,
                    edgeAnimationEnabled: Bool) {
        self.inputObserver = data.downstreamRowObserver
        self.upstreamObserver = data.upstreamRowObserver
        self.inputData = data.inputData
        self.outputData = data.outputData
        self.edgeAnimationEnabled = edgeAnimationEnabled
    }
//    @MainActor
//    init?(inputObserver: InputNodeRowViewModel,
//          outputObserver: OutputNodeRowViewModel,
//          edgeAnimationEnabled: Bool) {
//        let downstreamNode = inputObserver.nodeDelegate
//        
//        guard let inputData = EdgeAnchorDownstreamData(
//            from: inputObserver,
//            upstreamNodeId: outputObserver.canvasItemDelegate?.id),
//              let outputData = EdgeAnchorUpstreamData(
//                from: outputObserver,
//                connectedDownstreamNode: downstreamNode) else {
//            return nil
//        }
//        
//        self.inputData = inputData
//        self.outputData = outputData
//        self.upstreamObserver = outputObserver
//        self.inputObserver = inputObserver
//        self.edgeAnimationEnabled = edgeAnimationEnabled
//    }
    
//    @MainActor
//    init(inputObserver: InputNodeRowViewModel,
//         outputObserver: OutputNodeRowViewModel?,
//         possibleEdgeOutputObserver: OutputNodeRowViewModel?,
//         possibleEdge: PossibleEdge?,
//         edgeAnimationEnabled: Bool,
//         shownPossibleEdgeIds: Set<PossibleEdgeId>) {
//        let downstreamNode = inputObserver.nodeDelegate
//        // Needs to have at least a connected output or a "possible" output
//        let outputObserverForData = outputObserver ?? possibleEdgeOutputObserver
//        self.inputData = .init(from: inputObserver,
//                               upstreamNodeId: outputObserverForData?.canvasItemDelegate?.id)
//        self.outputData = .init(from: outputObserverForData,
//                                connectedDownstreamNode: downstreamNode)
//        
//        self.upstreamObserver = outputObserver
//        self.inputObserver = inputObserver
//        self.edgeAnimationEnabled = edgeAnimationEnabled
//        self.possibleEdge = possibleEdge
//        self.possibleEdgeOutputObserver = possibleEdgeOutputObserver
//        self.shownPossibleEdgeIds = shownPossibleEdgeIds
//    }
}

struct ConnectedEdgeView: View {

    @Environment(\.appTheme) private var theme
    @Environment(\.edgeStyle) private var edgeStyle
    
    @Bindable var inputObserver: InputNodeRowViewModel
    @Bindable var upstreamObserver: OutputNodeRowViewModel
    let inputData: EdgeAnchorDownstreamData
    let outputData: EdgeAnchorUpstreamData
    let edgeAnimationEnabled: Bool
    
    // Optional in event we only have possible edge
//    let upstreamObserver: OutputNodeRowViewModel?
    
//    let possibleEdge: PossibleEdge?
//    let possibleEdgeOutputObserver: OutputNodeRowViewModel?
//    let shownPossibleEdgeIds: Set<PossibleEdgeId>
        
    var body: some View {
        let firstUpstreamObserver = inputData.firstInputObserver
        let firstInputObserver = inputData.firstInputObserver
        let lastInputObserver = inputData.lastInputObserver
        let firstConnectedInputObserver = inputData.firstConnectedInputObserver
        let lastConnectedInputObserver = inputData.lastConectedInputObserver
        let lastUpstreamObserver = outputData.lastUpstreamObserver
        let totalOutputs = outputData.totalOutputs
        let lastConnectedUpstreamObserver = outputData.lastConnectedUpstreamObserver
//        let pointTo = inputObserver.anchorPoint
        
//        let possibleEdge = possibleEdge
//        let possibleEdgeOutputObserver = possibleEdgeOutputObserver
//        let shownPossibleEdgeIds = shownPossibleEdgeIds
        
        if let inputPortViewData = inputObserver.portViewData,
           let outputPortViewData = upstreamObserver.portViewData,
           let pointTo = inputObserver.anchorPoint,
           let pointFrom = upstreamObserver.anchorPoint,
           let firstFrom = firstUpstreamObserver.anchorPoint,
           let firstTo = firstInputObserver.anchorPoint,
           let lastFrom = lastUpstreamObserver.anchorPoint,
           let lastTo = lastInputObserver.anchorPoint,
           let firstFromWithEdge = firstConnectedInputObserver.anchorPoint?.y,
           let lastFromWithEdge = lastConnectedUpstreamObserver.anchorPoint?.y,
           let firstToWithEdge = firstConnectedInputObserver.anchorPoint?.y,
           let lastToWithEdge = lastConnectedInputObserver.anchorPoint?.y {
            let edge = PortEdgeUI(from: outputPortViewData,
                                  to: inputPortViewData)
            let portColor: PortColor = inputObserver.portColor
            let isSelectedEdge = (portColor == .highlightedEdge || portColor == .highlightedLoopEdge)
            
            // TODO: this is a problem with delegates
            
            let upstreamObserverZIndex = upstreamObserver.canvasItemDelegate?.zIndex ?? 0
            let defaultInputNodeIndex = inputObserver.canvasItemDelegate?.zIndex ?? 0
            let zIndexOfInputNode = inputObserver.canvasItemDelegate?.zIndex ?? defaultInputNodeIndex
            let base = max(upstreamObserverZIndex, zIndexOfInputNode)
            let boost = isSelectedEdge ? SELECTED_EDGE_Z_INDEX_BOOST : 0
            let zIndex: ZIndex = base + boost
            
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
            .zIndex(zIndex)
            
        } else {
            Color.clear
        }
            
        // Place possible-edges above existing edges
//        if let possibleEdge = possibleEdge,
//           let possibleEdgeOutputObserver = possibleEdgeOutputObserver {
//            PossibleEdgeView(edgeStyle: edgeStyle,
//                             possibleEdge: possibleEdge,
//                             shownPossibleEdgeIds: shownPossibleEdgeIds,
//                             from: possibleEdgeOutputObserver.anchorPoint ?? .zero,
//                             to: pointTo,
//                             totalOutputs: totalOutputs,
//                             // Note: an animated edit-mode edge use its output's color, rather than input's color, since the input will be gray until animation is completed
//                             color: possibleEdgeOutputObserver.portColor.color(theme))
//        }
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
