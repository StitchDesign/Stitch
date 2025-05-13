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

    private var visibleNodesViewModel: VisibleNodesViewModel {
        self.graph.visibleNodesViewModel
    }
        
    var body: some View {
        InfiniteCanvas(graph: graph,
                       existingCache: graph.visibleNodesViewModel.infiniteCanvasCache,
                       needsInfiniteCanvasCacheReset: graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset) {
            // commentBoxes
            NodesOnlyView(document: document, graph: graph)
        }
           .modifier(CanvasEdgesViewModifier(document: document, graph: graph))
        
        // TODO: completely remove?
           .transition(.groupTraverse(isVisitingChild: groupTraversedToChild,
                                      nodeLocation: .zero,
                                      graphOffset: .zero))
        
        // Can we move this ?
           .coordinateSpace(name: Self.coordinateNameSpace)

        // Scales and offsets the nodes, edges etc.
           .modifier(StitchUIScrollViewModifier(document: document,
                                                graph: graph))
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
    
}

struct CanvasEdgesViewModifier: ViewModifier {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    
    func body(content: Content) -> some View {
        content
            .background {
                // Using background ensures edges z-index are always behind ndoes
                GraphConnectedEdgesView(graph: graph)
                CandidateEdgesView(graph: graph)
            }
        
//        // BAD: scaling the UIScrollView also moves the
//            .overlay(alignment: .trailing) {
//                // OPTION #1: don't use .inspector
//                LayerInspectorView(graph: graph, document: document)
//                    .frame(
//                        width: LayerInspectorView.LAYER_INSPECTOR_WIDTH / self.document.graphMovement.zoomData,
//                        height: 600 / self.document.graphMovement.zoomData
//                    )
//                    .position(
//                        x: self.document.graphMovement.localPosition.x / self.document.graphMovement.zoomData,
//                        y: self.document.graphMovement.localPosition.y / self.document.graphMovement.zoomData
//                    )
//                    .scaleEffect(1/self.document.graphMovement.zoomData)
//            }
//
            .overlay {
                
                EdgeDrawingView(graph: graph,
                                edgeDrawingObserver: graph.edgeDrawingObserver)
                
//                // OPTION #1: don't use .inspector
//                LayerInspectorView(graph: graph, document: document)
//                    .frame(width: LayerInspectorView.LAYER_INSPECTOR_WIDTH / self.document.graphMovement.zoomData,
//                           height: 600 / self.document.graphMovement.zoomData)
//                    .position(
//                        x: self.document.graphMovement.localPosition.x / self.document.graphMovement.zoomData,
//                        y: self.document.graphMovement.localPosition.y / self.document.graphMovement.zoomData
//                    )
                //                    .zIndex(999999999999999)
                
               
                
                if let edgeEditingState = graph.edgeEditingState {
                    EdgeInputLabelsView(document: document,
                                        graph: graph,
                                        edgeEditingState: edgeEditingState)
                }
                
                
                
                if let openPortPreview = document.openPortPreview,
                   let canvas = graph.getCanvasItem(openPortPreview.canvasItemId) {
                    PortPreviewPopoverWrapperView(
                        openPortPreview: openPortPreview,
                        activeIndex: document.activeIndex,
                        canvas: canvas)
                }
            }

    }
}
