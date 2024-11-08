//
//  NodesOnlyView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/28/23.
//

import SwiftUI
import StitchSchemaKit

struct NodesOnlyView: View {

    @Bindable var document: StitchDocumentViewModel
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
        let filteredCanvasNodes = canvasNodes.filter { $0.parentGroupNodeId == graphUI.groupNodeFocused?.groupNodeId }
        
        // HACK for when no nodes present
        if filteredCanvasNodes.isEmpty {
            Rectangle().fill(.clear)
        }

        ForEach(filteredCanvasNodes) { canvasNode in
            // Note: if/else seems better than opacity modifier, which introduces funkiness with edges (port preference values?) when going in and out of groups;
            // (`.opacity(0)` means we still render the view, and thus anchor preferences?)
            NodeTypeView(
                document: document,
                graph: graph,
                node: canvasNode.nodeDelegate ?? .init(),
                canvasNode: canvasNode,
                atleastOneCommentBoxSelected: selection.selectedCommentBoxes.count >= 1,
                activeIndex: activeIndex,
                groupNodeFocused: graphUI.groupNodeFocused,
                adjustmentBarSessionId: adjustmentBarSessionId,
                isHiddenDuringAnimation: insertNodeMenuHiddenNode
                    .map { $0 == canvasNode.nodeDelegate?.id } ?? false
            )
            .onChange(of: self.activeIndex) {
                // Update values when active index changes
                self.canvasNodes.forEach { canvasNode in
                    canvasNode.nodeDelegate?.activeIndexChanged(activeIndex: self.activeIndex)
                }
            }
        }
    }
}

// struct NodesOnlyView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodesOnlyView()
//    }
// }
