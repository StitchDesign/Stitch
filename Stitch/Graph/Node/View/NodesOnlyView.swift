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

        //        FakeLayerInputOnGraphView().zIndex(9999)
        
        ForEach(nodes) { node in
            // Note: if/else seems better than opacity modifier, which introduces funkiness with edges (port preference values?) when going in and out of groups;
            // (`.opacity(0)` means we still render the view, and thus anchor preferences?)
            let isAtThisTraversalLevel = node.parentGroupNodeId == graphUI.groupNodeFocused?.asNodeId
            let isNotLayerNode = !node.layerNode.isDefined
            
            if isAtThisTraversalLevel && isNotLayerNode {
                NodeTypeView(
                    graph: graph,
                    node: node,
                    atleastOneCommentBoxSelected: selection.selectedCommentBoxes.count >= 1,
                    activeIndex: activeIndex,
                    groupNodeFocused: graphUI.groupNodeFocused,
                    adjustmentBarSessionId: adjustmentBarSessionId,
                    isHiddenDuringAnimation: insertNodeMenuHiddenNode
                        .map { $0 == node.id } ?? false
                )
            } else {
                EmptyView()
            }
        }
        .onChange(of: self.activeIndex) {
            // Update values when active index changes
            self.nodes.forEach { node in
                node.activeIndexChanged(activeIndex: self.activeIndex)
            }
        }
    }
}    

// struct NodesOnlyView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodesOnlyView()
//    }
// }
