//
//  NodesView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

struct PatchCanvasEmptyStateView: View {
    let document: StitchDocumentViewModel
    
    var body: some View {
        ProjectEmptyStateView(title: "Patch Canvas",
                              description: "Add patch nodes here.") {
            NodeEmptyStateAboutButtonsView(isPatch: true,
                                           document: document)
        }
                              .frame(width: NodeEmptyStateAboutButtonsView.defaultWidth)
                              .padding()
                              .background(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE)
                              .cornerRadius(16)
    }
}

struct NodesView: View {
    static let coordinateNamespace = "NODESVIEW"
    
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
                       needsInfiniteCanvasCacheReset: graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset
        ) {
            // commentBoxes
            NodesOnlyView(document: document, graph: graph)
            
            //            #if DEV || DEV_DEBUG
            //            // NOTE: ONLY FOR READING SIZE OF ALL PATCH X NODE-TYPE COMBINATIONS
            //            // NEVER CALLED FOR PRODUCTION; ONLY CALLED IN DEBUG WHEN E.G. WE HAVE A NEW `Patch`, `NodeType` OR `LayerInputPort`
            //                .modifier(PSEUDO_SCRIPT_READ_PATCH_NODE_AND_LAYER_INPUT_SIZES(document: document))
            //            #endif
            
        }
           .modifier(CanvasEdgesViewModifier(document: document, graph: graph))
        
        // TODO: completely remove?
           .transition(.groupTraverse(isVisitingChild: groupTraversedToChild,
                                      nodeLocation: .zero,
                                      graphOffset: .zero))
        
        // Can we move this ?
           .coordinateSpace(name: Self.coordinateNamespace)

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
            .overlay {
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
