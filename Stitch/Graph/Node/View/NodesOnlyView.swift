//
//  NodesOnlyView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/28/23.
//

import SwiftUI
import StitchSchemaKit

struct NodesOnlyView: View {

    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var nodePageData: NodePageData
    let nodes: NodeViewModels
    let insertNodeMenuHiddenNode: NodeId?
    
    var selection: GraphUISelectionState {
        graphUI.selection
    }
    
    var activeIndex: ActiveIndex {
        graphUI.activeIndex
    }
    
    var adjustmentBarSessionId: AdjustmentBarSessionId {
        graphUI.adjustmentBarSessionId
    }
        
    var body: some View {
        // HACK for when no nodes present
        if nodes.isEmpty {
            Rectangle().fill(.clear)
        }
        
        // Does ZStack e.g. put LIG views on top of patch node views?
        ZStack {
            patchOrGroupNodesView
            layerInputsOnGraphView
        }
        .onChange(of: self.activeIndex) {
            // Update values when active index changes
            self.nodes.forEach { node in
                node.activeIndexChanged(activeIndex: self.activeIndex)
            }
        }
    }
    
    var currentlyFocusedGroup: NodeId? {
        graphUI.groupNodeFocused?.asNodeId
    }
        
    @MainActor @ViewBuilder
    var layerInputsOnGraphView: some View {
        let layerNodes = self.nodes.filter(\.layerNode.isDefined)
        ForEach(layerNodes) { node in
            // TODO: only show those LIG at this traversal level
            let inputsOnGraph = node.inputRowObservers().filter(\.canvasUIData.isDefined)
            
            ForEach(inputsOnGraph) { inputOnGraph in
                let isAtThisTraversalLevel = inputOnGraph.canvasUIData?.parentGroupNodeId == currentlyFocusedGroup
                
                if isAtThisTraversalLevel,
                   let layerNode = node.layerNode {
                    LayerInputOnGraphView(
                        graph: graph,
                        node: node,
                        input: inputOnGraph,
                        canvasItem: inputOnGraph.canvasUIData!,
                        layerNode: layerNode)
                } else {
                    EmptyView().onAppear {
                        if !node.layerNode.isDefined {
                            fatalErrorIfDebug()
                        }
                    }
                }
            }
        }
    }
    
    @MainActor @ViewBuilder
    var patchOrGroupNodesView: some View {
        let patchOrGroupNodes = self.nodes.filter { !$0.kind.isLayer }
        ForEach(patchOrGroupNodes) { node in
            // Note: if/else seems better than opacity modifier, which introduces funkiness with edges (port preference values?) when going in and out of groups;
            // (`.opacity(0)` means we still render the view, and thus anchor preferences?)
            let isAtThisTraversalLevel = node.parentGroupNodeId == currentlyFocusedGroup
            if isAtThisTraversalLevel {
                NodeTypeView(
                    graph: graph,
                    node: node,
                    atleastOneCommentBoxSelected: selection.selectedCommentBoxes.count >= 1,
                    activeIndex: activeIndex,
                    groupNodeFocused: graphUI.groupNodeFocused,
                    adjustmentBarSessionId: adjustmentBarSessionId,
                    isHiddenDuringAnimation: insertNodeMenuHiddenNode.map { $0 == node.id } ?? false
                )
            } else {
                EmptyView()
            }
        }
    }
}

// struct NodesOnlyView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodesOnlyView()
//    }
// }
