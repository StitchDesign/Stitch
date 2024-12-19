//
//  GraphMovementViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/4/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GraphMovementViewModifier: ViewModifier {
    @Bindable var graphMovement: GraphMovementObserver
    @Bindable var currentNodePage: NodePageData
    @Bindable var graph: GraphState
    let groupNodeFocused: GroupNodeType?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                self.graph.updateVisibleNodes()
            }
            .onChange(of: groupNodeFocused, initial: true) {
                self.graphMovement.localPosition = currentNodePage.localPosition
                self.graphMovement.localPreviousPosition = currentNodePage.localPosition
                self.graphMovement.zoomData.current = currentNodePage.zoomData.current
                self.graphMovement.zoomData.final = currentNodePage.zoomData.final
                
                self.graph.updateVisibleNodes()
            }
        
        // NOTE: DEC 12: we DO want all these updates
            .onChange(of: graphMovement.localPosition) { _, newValue in
                log("GraphMovementViewModifier: changed: graphMovement.localPosition: newValue: \(newValue)")
                currentNodePage.localPosition = graphMovement.localPosition
                
                self.graph.updateVisibleNodes()
            }
            .onChange(of: graphMovement.zoomData.current) { _, newValue in
                log("GraphMovementViewModifier: changed: graphMovement.zoomData.current: newValue: \(newValue)")
                currentNodePage.zoomData.current = graphMovement.zoomData.current
            }
            .onChange(of: graphMovement.zoomData.final) { _, newValue in
                log("GraphMovementViewModifier: changed: graphMovement.zoomData.final: newValue: \(newValue)")
                currentNodePage.zoomData.final = graphMovement.zoomData.final
                
                self.graph.updateVisibleNodes()
            }
        
        // offset and scale are applied to the nodes on the graph,
        // but not eg to the blue box and green cursor;
        // GRAPH-OFFSET (applied to container for all the nodes)
        //            .offset(x: graphMovement.localPosition.x,
        //                    y: graphMovement.localPosition.y)
        //        // SCALE APPLIED TO GRAPH-OFFSET + ALL THE NODES
        //            .scaleEffect(graphMovement.zoomData.zoom)
        
    }
}
    
extension GraphState {
    /// Accomplishes the following tasks:
    /// 1. Determines which nodes are visible.
    /// 2. Determines which nodes are selected from the selection box, if applicable.
    @MainActor
    func updateVisibleNodes() {
//        let zoom = 1 / self.graphMovement.zoomData.zoom
        let origin = self.graphMovement.localPosition
        let viewFrameSize = self.graphUI.frame.size
        
        var newVisibleNodes = Set<CanvasItemId>()
        
        // Calculate view frame dependencies
//        let viewframeOrigin = CGPoint(x: -origin.x,
//                                      y: -origin.y)
        
        // Now, localPosition is just offset from the top left corner;
        // can never have negative offset.
        let viewframeOrigin = CGPoint(x: origin.x, y: origin.y)
        
//        log("updateVisibleNodes: self.graphMovement.zoomData.zoom: \(self.graphMovement.zoomData.zoom)")
//        log("updateVisibleNodes: zoom: \(zoom)")
        log("updateVisibleNodes: origin: \(origin)")
        
        let graphView = CGRect(origin: viewframeOrigin,
                               size: viewFrameSize)
        
        log("updateVisibleNodes: graphView.origin: \(graphView.origin)")
        log("updateVisibleNodes: graphView.size: \(graphView.size)")
        
//        let viewFrame = Self.getScaledViewFrame(scale: zoom,
//                                                graphView: graphView)
        let viewFrame = Self.getScaledViewFrame(scale: 1,
                                                graphView: graphView)
        
        log("updateVisibleNodes: viewFrame.origin: \(viewFrame.origin)")
        log("updateVisibleNodes: viewFrame.size: \(viewFrame.size)")
        
        // Determine nodes to make visible--use cache in case nodes exited viewframe
        for cachedSubviewData in self.visibleNodesViewModel.infiniteCanvasCache {
            let id = cachedSubviewData.key
            let cachedBounds = cachedSubviewData.value
            
            log("updateVisibleNodes: id \(id)")
            log("updateVisibleNodes: cachedBounds.origin \(cachedBounds.origin)")
            log("updateVisibleNodes: cachedBounds.size \(cachedBounds.size)")
            
            let isVisibleInFrame = viewFrame.intersects(cachedBounds)
            if isVisibleInFrame {
                log("updateVisibleNodes: visible")
                newVisibleNodes.insert(id)
            } else {
                log("updateVisibleNodes: NOT visible")
            }
        }
        
        if self.visibleNodesViewModel.visibleCanvasIds != newVisibleNodes {
            self.visibleNodesViewModel.visibleCanvasIds = newVisibleNodes
        }
        
        log("updateVisibleNodes: visibleNodesViewModel.visibleCanvasIds is now: \(visibleNodesViewModel.visibleCanvasIds)")
        
        // WHAT? WE WERE ALWAYS updating the visible canvas ids, even if they were the same?
//        self.visibleNodesViewModel.visibleCanvasIds = newVisibleNodes
        
    }
        
    
    /// Uses graph local offset and scale to get a modified `CGRect` of the view frame.
    static func getScaledViewFrame(scale: Double,
                                   graphView: CGRect) -> CGRect {
        let scaledSize = CGSize(
            width: graphView.width * scale,
            height: graphView.height * scale)

        let yDiff = (graphView.height - scaledSize.height) / 2
        let xDiff = (graphView.width - scaledSize.width) / 2
        
        return CGRect(origin: CGPoint(x: graphView.origin.x + xDiff,
                                      y: graphView.origin.y + yDiff),
                      size: scaledSize)
    }
    
    /// Uses graph local offset and scale to get a modified `CGRect` of the selection box view frame.
    static func getScaledSelectionBox(selectionBox: CGRect,
                                      scale: Double,
                                      scaledViewFrameOrigin: CGPoint) -> CGRect? {
        guard selectionBox != .zero else { return nil }
        
        let scaledSelectionBoxSize = CGSize(
            // must explicitly graph .size to get correct magnitude
            width: selectionBox.size.width * scale,
            height: selectionBox.size.height * scale)
        
        let scaledOrigin = CGPoint(x: selectionBox.origin.x * scale,
                                   y: selectionBox.origin.y * scale)
        
        let scaledSelectionBox = CGRect(origin: scaledOrigin + scaledViewFrameOrigin,
                                           size: scaledSelectionBoxSize)
//                print("infinite selection origin: \(selectionBox.origin)")
//                print("infinite selection size: \(selectionBox.size)")
//                print("infinite selection final: \(selectionBoxViewFrame)")
//                print("infinite node: \(cachedBounds)")
        
        return scaledSelectionBox
    }
}
