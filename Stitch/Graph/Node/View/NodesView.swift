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
        InfiniteCanvas(graph: graph,
                       existingCache: graph.visibleNodesViewModel.infiniteCanvasCache,
                       needsInfiniteCanvasCacheReset: graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset) {
            
            //                        commentBoxes
            
            nodesOnlyView()
        }
           .modifier(CanvasEdgesViewModifier(document: document,
                                             graph: graph))
        
           .transition(.groupTraverse(isVisitingChild: groupTraversedToChild,
                                      nodeLocation: groupNodeLocation,
                                      graphOffset: .zero))
        
           .coordinateSpace(name: Self.coordinateNameSpace)

        // should come after edges, so that edges are offset, scaled etc.
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
    
    @MainActor
    func nodesOnlyView() -> some View {
        NodesOnlyView(document: document,
                      graph: graph)
    }
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
            .overlay {
                EdgeDrawingView(graph: graph,
                                edgeDrawingObserver: graph.edgeDrawingObserver)
                
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
