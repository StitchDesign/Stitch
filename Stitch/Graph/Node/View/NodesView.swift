//
//  NodesView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

struct NodesView: View {
    static let coordinateNameSpace = "NODESVIEW"
    
    // Manages visible nodes array to animate instances when a group node changes
    @Bindable var graph: GraphState
    let groupNodeFocused: GroupNodeId?
    
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
                .getViewData(groupNodeFocused: groupNodeFocused) {
                                
                let inputs: NodeRowObservers = self.graph
                    .getVisibleCanvasItems()
                    .flatMap { canvasItem -> NodeRowObservers in
                        
                        switch canvasItem.id {
                            
                        case .layerInputOnGraph(let x):
                            guard let input = graph.getInputObserver(coordinate: x.asInputCoordinate) else {
                                return []
                            }
                            return [input]
                            
                        case .node(let x):
                            // Hides edges from group input splitters
                            // and from wireless receiver nodes
                            guard let node = graph.getNode(x) else {
                                log("could not find node")
                                return []
                            }
                            
                            if node.splitterType == .input ||
                                node.patch == .wirelessReceiver {
                                log("had an input splitter or wireless receiver")
                                return []
                            }
                            
                            return node.inputRowObservers()
                        }
                    }
                
                
                ZStack {
                    // CommentBox needs to be affected by graph offset and zoom
                    // but can live somewhere else?
                    ZStack {
//                        commentBoxes
                        nodesOnlyView(nodePageData: nodePageData)
                    }
                    .background {
                        // Using background ensures edges z-index are always behind ndoes
                        connectedEdgesView(allInputs: inputs)
                    }
                    .overlay {
                        edgeDrawingView(inputs: inputs)
                        EdgeInputLabelsView(inputs: inputs,
                                            graph: graph,
                                            graphUI: graph.graphUI)
                    }
                    .transition(.groupTraverse(isVisitingChild: groupTraversedToChild,
                                               nodeLocation: groupNodeLocation,
                                               graphOffset: .zero))
                }
                .coordinateSpace(name: Self.coordinateNameSpace)
                .modifier(GraphMovementViewModifier(graphMovement: graph.graphMovement,
                                                    currentNodePage: nodePageData,
                                                    groupNodeFocused: groupNodeFocused))
            } else {
                EmptyView()
            }
        }
        .onChange(of: groupNodeFocused) {
            // Updates cached data inside row observers when group changes
            self.visibleNodesViewModel.updateAllNodeViewData()
        }
    }
    
    @MainActor
    func connectedEdgesView(allInputs: NodeRowObservers) -> some View {
        GraphConnectedEdgesView(graph: graph,
                                graphUI: graphUI,
                                allInputs: allInputs)
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
        NodesOnlyView(graph: graph,
                      graphUI: graphUI,
                      nodePageData: nodePageData,
                      nodes: visibleNodesViewModel.allViewModels,
                      insertNodeMenuHiddenNode: insertNodeMenuHiddenNodeId)
    }
    
    @MainActor
    func edgeDrawingView(inputs: NodeRowObservers) -> some View {
        EdgeDrawingView(edgeDrawingObserver: graph.edgeDrawingObserver,
                        inputsAtThisTraversalLevel: inputs)
    }
}


struct EdgeInputLabelsView: View {
    let inputs: NodeRowObservers
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState

    var body: some View {
        let showLabels = graph.graphUI.edgeEditingState?.labelsShown ?? false
        let nearbyNodeId = graph.graphUI.edgeEditingState?.nearbyNode
        
        ForEach(inputs) { inputRowObserver in
            // visibleNodeId property checks for group splitter inputs
            let isInputForNearbyNode = nearbyNodeId == inputRowObserver.visibleNodeId
            let isVisible = isInputForNearbyNode && showLabels
            
            EdgeEditModeLabelsView(graph: graph,
                                   portId: inputRowObserver.portViewType?.input?.portId ?? .zero)
            .position(inputRowObserver.anchorPoint ?? .zero)
            .opacity(isVisible ? 1 : 0)
            .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                       value: isVisible)
        }
    }
}
