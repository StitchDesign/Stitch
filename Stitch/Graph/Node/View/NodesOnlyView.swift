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
    
    var canvasNodeIds: [CanvasItemId] {
        self.graph.visibleNodesViewModel.allViewModels.map(\.id)
    }

    var selection: GraphUISelectionState {
        graphUI.selection
    }
    
    var activeIndex: ActiveIndex {
        graphUI.activeIndex
    }
    
    var adjustmentBarSessionId: AdjustmentBarSessionId {
        graphUI.adjustmentBarSessionId
    }
    
    var focusedGroup: GroupNodeType? {
        self.graph.graphUI.groupNodeFocused
    }
        
    var body: some View {
        // HACK for when no nodes present
        if canvasNodeIds.isEmpty {
            Rectangle().fill(.clear)
        }
        
        #if DEV_DEBUG
        // scrollView.contentOffset without taking scrollView.zoomScale into account
        Circle().fill(.yellow.opacity(0.95))
            .frame(width: 60, height: 60)
            .position(self.document.graphMovement.localPosition)
            .zIndex(999999999999999)
        
        // scrollView.contentOffset WITH taking scrollView.zoomScale into account
        Circle().fill(.black.opacity(0.95))
            .frame(width: 60, height: 60)
            .position(
                x: self.document.graphMovement.localPosition.x / self.document.graphMovement.zoomData.final,
                y: self.document.graphMovement.localPosition.y / self.document.graphMovement.zoomData.final
            )
            .zIndex(999999999999999)
        #endif

        let canvasNodes: [CanvasItemViewModel] = canvasNodeIds
            .compactMap { id in
                guard let canvas = self.graph.getCanvasItem(id),
                      canvas.parentGroupNodeId == self.focusedGroup?.groupNodeId else {
                    return nil
                }
                
                return canvas
            }

        ForEach(canvasNodes) { canvasNode in
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
                isSelected: graphUI.selection.selectedNodeIds.contains(canvasNode.id)
            )
        }
        .onChange(of: self.activeIndex) {
            // Update values when active index changes
            canvasNodes.forEach { canvasNode in
                canvasNode.nodeDelegate?.activeIndexChanged(activeIndex: self.activeIndex)
            }
        }
        .onChange(of: self.focusedGroup) {
            // Update node locations
            self.graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
        }
    }
}
