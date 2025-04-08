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
    
    var canvasNodes: [CanvasItemViewModel] {
        graph.visibleCanvasNodes
    }
    
    var selection: GraphUISelectionState {
        graph.selection
    }
    
    var activeIndex: ActiveIndex {
        document.activeIndex
    }
    
    var focusedGroup: GroupNodeType? {
        document.groupNodeFocused
    }
        
    var body: some View {
        Group {
            // HACK for when no nodes present
            if canvasNodes.isEmpty {
                Rectangle().fill(.clear)
                //                .onAppear() {
                //                    self.refreshCanvasNodes()
                //                }
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
                    x: self.document.graphMovement.localPosition.x / self.document.graphMovement.zoomData,
                    y: self.document.graphMovement.localPosition.y / self.document.graphMovement.zoomData
                )
                .zIndex(999999999999999)
#endif
            
            // Bad
//            let dotOffsetX = ABSOLUTE_GRAPH_CENTER.x - self.document.graphMovement.localPosition.x
//            let dotOffsetY = ABSOLUTE_GRAPH_CENTER.y - self.document.graphMovement.localPosition.y

            // Decent
//            let dotOffsetX = self.document.graphMovement.localPosition.x - ABSOLUTE_GRAPH_CENTER.x
//            let dotOffsetY = self.document.graphMovement.localPosition.y - ABSOLUTE_GRAPH_CENTER.y
            
////            DotsBackgroundView(color: .gray.opacity(0.75))
//            DotsBackgroundView(color: .red)
//                .position(x: ABSOLUTE_GRAPH_CENTER.x,
//                          y: ABSOLUTE_GRAPH_CENTER.y)
//                .allowsHitTesting(false)
////                .opacity(1 * (document.graphMovement.zoomData))
////                .offset(x: dotOffsetX, y: dotOffsetY)
//            
//            logInView("NodesOnlyView: document.graphMovement.zoomData: \(document.graphMovement.zoomData)")
//            
//            // this position is relative to the top left corner (0,0) of the 300k x 300k size graph
//            logInView("NodesOnlyView: document.graphMovement.localPosition: \(document.graphMovement.localPosition)")
//            logInView("NodesOnlyView: dotOffsetX: \(dotOffsetX)")
//            logInView("NodesOnlyView: dotOffsetY: \(dotOffsetY)")
            
            // e.g. content offset i.e. local position of absolute center = 150k x 150k
            
            ForEach(canvasNodes) { canvasNode in
                // Note: if/else seems better than opacity modifier, which introduces funkiness with edges (port preference values?) when going in and out of groups;
                // (`.opacity(0)` means we still render the view, and thus anchor preferences?)
                
                if let node = graph.getNodeViewModel(canvasNode.id.nodeId) {                    
                    NodeView(node: canvasNode,
                             stitch: node,
                             document: document,
                             graph: graph,
                             nodeId: node.id,
                             isSelected: graph.selection.selectedCanvasItems.contains(canvasNode.id),
                             atleastOneCommentBoxSelected: selection.selectedCommentBoxes.count >= 1,
                             activeGroupId: document.groupNodeFocused,
                             canAddInput: node.canAddInputs,
                             canRemoveInput: node.canRemoveInputs,
                             boundsReaderDisabled: false,
                             updateMenuActiveSelectionBounds: false)
                }
            }
        }
        .onChange(of: self.activeIndex) {
            // Update values when active index changes
            graph.nodes.values.forEach { node in
                node.activeIndexChanged(activeIndex: self.activeIndex)
            }
        }
        // Also do this on `initial: true` ?
        .onChange(of: self.focusedGroup) {
            // Update node locations
            self.graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
        }
    }
}


//// Canvas approach is much faster than LazyVGrid
//struct DotsBackgroundView: View {
//    
//    let color: Color
//    
//    // Not big enough for zoom = 0.1, but big enough for e.g. zoom = 0.21
////    let rows = 300
////    let columns = 300
//    
//    // Not quite enough for zoom ~= 0.22
////    let rows = 160
////    let columns = 160
//    
////    let rows = 200
////    let columns = 200
//    
////    let rows = 600
////    let columns = 600
////    let rows = 400
////    let columns = 400
//    
////    let rows = 350
////    let columns = 350
//
//    let rows = 325
//    let columns = 325
////    let rows = 340
////    let columns = 340
//    
//    // so many rows/columns that we don't even render them, Canvas freaks out?
////    let rows = 600
////    let columns = 600
//    let spacing: CGFloat = SQUARE_SIDE_LENGTH_AS_CGFLOAT
//    let circleDiameter: CGFloat = 3
//    
//    var body: some View {
//        Canvas { context, size in
//            for row in 0..<rows {
//                for col in 0..<columns {
//                    let x = CGFloat(col) * spacing
//                    let y = CGFloat(row) * spacing
//                    let circle = Path(ellipseIn: CGRect(x: x,
//                                                        y: y,
//                                                        width: circleDiameter,
//                                                        height: circleDiameter))
//                    context.fill(circle, with: .color(color))
//                }
//            }
//        }
//        .frame(width: CGFloat(columns) * spacing, height: CGFloat(rows) * spacing)
//    }
//}
