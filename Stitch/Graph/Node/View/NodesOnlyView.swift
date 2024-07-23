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
    let canvasNodes: [CanvasItemViewModel]
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
        if canvasNodes.isEmpty {
            Rectangle().fill(.clear)
        }

        ForEach(canvasNodes) { canvasNode in
            // Note: if/else seems better than opacity modifier, which introduces funkiness with edges (port preference values?) when going in and out of groups;
            // (`.opacity(0)` means we still render the view, and thus anchor preferences?)
            if let node = canvasNode.nodeDelegate as? NodeViewModel,
               canvasNode.parentGroupNodeId == graphUI.groupNodeFocused?.asNodeId {
                NodeTypeView(
                    graph: graph,
                    node: node,
                    canvasNode: canvasNode,
                    atleastOneCommentBoxSelected: selection.selectedCommentBoxes.count >= 1,
                    activeIndex: activeIndex,
                    groupNodeFocused: graphUI.groupNodeFocused,
                    adjustmentBarSessionId: adjustmentBarSessionId,
                    isHiddenDuringAnimation: insertNodeMenuHiddenNode
                        .map { $0 == node.id } ?? false
                )
                .onChange(of: self.activeIndex) {
                    // Update values when active index changes
                    self.canvasNodes.forEach { canvasNode in
                        node.activeIndexChanged(activeIndex: self.activeIndex)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var currentlyFocusedGroup: NodeId? {
        graphUI.groupNodeFocused?.asNodeId
    }
}

// struct NodesOnlyView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodesOnlyView()
//    }
// }
