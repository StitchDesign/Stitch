//
//  NodesView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

struct NodesView: View {
    static let coordinateNameSpace = "NODESVIEW"
    
    @Bindable var document: StitchDocumentViewModel
    
    // Manages visible nodes array to animate instances when a group node changes
    @Bindable var graph: GraphState
    
    // animation state for group node traversals
    let groupTraversedToChild: Bool
    
    // State to help animate incoming node
    let insertNodeMenuHiddenNodeId: NodeId?

    private var visibleNodesViewModel: VisibleNodesViewModel {
        self.graph.visibleNodesViewModel
    }
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    // Finds a group node's offset from center, used for animating
    // group node traversals
    // TODO: group node location for transition
    var groupNodeLocation: CGPoint {
        .zero
        //        guard let groupNodeFocused = groupNodeFocused,
        //              let groupNode: GroupNode = groupNodesState[groupNodeFocused] else {
        //            return CGPoint.zero
        //        }
        //        return getNodeOffset(node: groupNode.schema,
        //                             graphViewFrame: graphFrame,
        //                             scale: zoom)
    }
    
    var body: some View {
        Group {
            if let nodePageData = visibleNodesViewModel
                .getViewData(groupNodeFocused: graphUI.groupNodeFocused?.groupNodeId) {
                
                let allInputs: [InputNodeRowViewModel] = self.graph
                    .getVisibleCanvasItems()
                    .flatMap { canvasItem -> [InputNodeRowViewModel] in
                        canvasItem.inputViewModels
                    }
                
                let connectedInputs = allInputs.filter { input in
                    guard input.nodeDelegate?.patchNodeViewModel?.patch != .wirelessReceiver else {
                        return false
                    }
                    return input.rowDelegate?.containsUpstreamConnection ?? false
                }
                
                // Including "possible" inputs enables edge animation
                let candidateInputs: [InputNodeRowViewModel] = graphUI.edgeEditingState?.possibleEdges.compactMap {
                    let inputData = $0.edge.to
                    
                    guard let node = self.graph.getCanvasItem(inputData.canvasId),
                          let inputRow = node.inputViewModels[safe: inputData.portId] else {
                        return nil
                    }
                    
                    return inputRow
                } ?? []
                
                // CommentBox needs to be affected by graph offset and zoom
                // but can live somewhere else?
                ZStack {
                    //                        commentBoxes
                    nodesOnlyView(nodePageData: nodePageData)
                }
                .background {
                    // Using background ensures edges z-index are always behind ndoes
                    connectedEdgesView(allConnectedInputs: connectedInputs + candidateInputs)
                }
                .overlay {
                    edgeDrawingView(inputs: allInputs,
                                    graph: self.graph)
                    
                    EdgeInputLabelsView(inputs: allInputs,
                                        document: document,
                                        graphUI: document.graphUI)
                }
                .transition(.groupTraverse(isVisitingChild: groupTraversedToChild,
                                           nodeLocation: groupNodeLocation,
                                           graphOffset: .zero))
                .coordinateSpace(name: Self.coordinateNameSpace)
                .modifier(GraphMovementViewModifier(graphMovement: graph.graphMovement,
                                                    currentNodePage: nodePageData,
                                                    groupNodeFocused: graphUI.groupNodeFocused))
            } else {
                Color.clear
                    .onAppear {
                        fatalErrorIfDebug()
                    }
            }
        }
//        .onChange(of: groupNodeFocused) {
//            // Updates cached data inside row observers when group changes
//            self.visibleNodesViewModel.updateAllNodeViewData()
//        }
    }
    
    @MainActor
    func connectedEdgesView(allConnectedInputs: [InputNodeRowViewModel]) -> some View {
        GraphConnectedEdgesView(graph: graph,
                                graphUI: graphUI,
                                allConnectedInputs: allConnectedInputs)
    }
    
    // TODO: better location for CommentBoxes?
//    var commentBoxes: some View {
//        ForEach(graph.commentBoxesDict.toValuesArray, id: \.id) { box in
//            CommentBoxView(
//                graph: graph,
//                box: box,
//                isSelected: selection.selectedCommentBoxes.contains(box.id))
//            .zIndex(box.zIndex)
//        }
//    }
    
    @MainActor
    func nodesOnlyView(nodePageData: NodePageData) -> some View {
        NodesOnlyView(document: document,
                      graph: graph,
                      graphUI: graphUI,
                      nodePageData: nodePageData,
                      canvasNodes: visibleNodesViewModel.allViewModels,
                      insertNodeMenuHiddenNode: insertNodeMenuHiddenNodeId)
    }
    
    @MainActor
    func edgeDrawingView(inputs: [InputNodeRowViewModel],
                         graph: GraphState) -> some View {
        EdgeDrawingView(graph: graph,
                        edgeDrawingObserver: graph.edgeDrawingObserver,
                        inputsAtThisTraversalLevel: inputs)
    }
}


struct EdgeInputLabelsView: View {
    let inputs: [InputNodeRowViewModel]
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState

    var body: some View {
        let showLabels = document.graphUI.edgeEditingState?.labelsShown ?? false
        
        if let nearbyCanvasItem: CanvasItemId = document.graphUI.edgeEditingState?.nearbyCanvasItem {
            ForEach(inputs) { inputRowViewModel in
                
                
                // Doesn't seem to be needed? Checking the canvasItemDelegate seems to work well
                // visibleNodeId property checks for group splitter inputs
//                let isInputForNearbyNode = inputRowViewModel.visibleNodeIds.contains(nearbyCanvasItem)
                
                let isInputOnNearbyCanvasItem = inputRowViewModel.canvasItemDelegate?.id == nearbyCanvasItem
                let isVisible = isInputOnNearbyCanvasItem && showLabels
                
                EdgeEditModeLabelsView(document: document,
                                       portId: inputRowViewModel.id.portId)
                .position(inputRowViewModel.anchorPoint ?? .zero)
                .opacity(isVisible ? 1 : 0)
                .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                           value: isVisible)
            }
        } else {
            EmptyView()
        }
    }
}
