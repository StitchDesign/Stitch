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
        // HACK: fixes hit area issue
        Rectangle().fill(.clear)
        
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
            let layerRowsOnGraph = (node.inputRowObservers() + node.outputRowObservers()).filter(\.canvasUIData.isDefined)
            
            ForEach(layerRowsOnGraph) { layerRowOnGraph in
                let isAtThisTraversalLevel = layerRowOnGraph.canvasUIData?.parentGroupNodeId == currentlyFocusedGroup
                                
                if isAtThisTraversalLevel,
                   let layerNode = node.layerNode {
                    LayerRowOnGraphView(
                        graph: graph,
                        node: node,
                        row: layerRowOnGraph,
                        canvasItem: layerRowOnGraph.canvasUIData!,
                        layerNode: layerNode)
                } else {
                    Color.clear.onAppear {
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
