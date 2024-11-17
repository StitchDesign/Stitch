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
            .onChange(of: graphMovement.localPosition, initial: true) {
                currentNodePage.localPosition = graphMovement.localPosition
            }
            .onChange(of: graphMovement.zoomData.current, initial: true) {
                currentNodePage.zoomData.current = graphMovement.zoomData.current
            }
            .onChange(of: graphMovement.zoomData.final, initial: true) {
                currentNodePage.zoomData.final = graphMovement.zoomData.final
            }
            .onChange(of: groupNodeFocused, initial: true) {
                self.graphMovement.localPosition = currentNodePage.localPosition
                self.graphMovement.localPreviousPosition = currentNodePage.localPosition
                self.graphMovement.zoomData.current = currentNodePage.zoomData.current
                self.graphMovement.zoomData.final = currentNodePage.zoomData.final
            }
            // offset and scale are applied to the nodes on the graph,
            // but not eg to the blue box and green cursor;
            // GRAPH-OFFSET (applied to container for all the nodes)
            .offset(x: graphMovement.localPosition.x,
                    y: graphMovement.localPosition.y)
            // SCALE APPLIED TO GRAPH-OFFSET + ALL THE NODES
            .scaleEffect(graphMovement.zoomData.zoom)
    }
    
    
    /// Accomplishes the following tasks:
    /// 1. Determines which nodes are visible.
    /// 2. Determines which nodes are selected from the selection box, if applicable.
    private func processVisibleNodes() -> CanvasItemIdSet {
        let zoom = 1 / self.graphMovement.zoomData.zoom
        let origin = self.graphMovement.localPosition
        let viewFrameSize = graph.graphUI.frame.size
        
        var visibleNodes = Set<CanvasItemId>()
        
        // Calculate view frame dependencies
        let viewframeOrigin = CGPoint(x: -origin.x,
                                      y: -origin.y)
        let graphView = CGRect(origin: viewframeOrigin,
                               size: viewFrameSize)
        let viewFrame = Self.getScaledViewFrame(scale: zoom,
                                                graphView: graphView)
//        let selectionBoxInViewFrame = Self.getScaledSelectionBox(selectionBox: selectionBox,
//                                                                 scale: zoom,
//                                                                 scaledViewFrameOrigin: viewFrame.origin)
//        let hasActiveSelectionBox = selectionBoxInViewFrame.isDefined
        
        // Determine nodes to make visible--use cache in case nodes exited viewframe
        for cachedSubviewData in graph.visibleNodesViewModel.infiniteCanvasCache ?? .init() {
            let id = cachedSubviewData.key
            let cachedBounds = cachedSubviewData.value
            
            let isVisibleInFrame = viewFrame.intersects(cachedBounds)
            if isVisibleInFrame {
                visibleNodes.insert(id)
            }
            
//            if nodesSelectedOnShift?.contains(id) ?? false {
//                log("skipping canvasItem \(id) since was held as part of shift etc.")
//                continue
//            }
            
//            if let selectionBoxInViewFrame = selectionBoxInViewFrame {
//                if selectionBoxInViewFrame.intersects(cachedBounds) {
//                    selectedNodes.insert(id)
//                }
//            }
        }
        
//        if hasActiveSelectionBox {
//            self.graph.graphUI.selection.selectedNodeIds = selectedNodes
//        }
        
        if graph.visibleNodesViewModel.visibleCanvasIds != visibleNodes {
            graph.visibleNodesViewModel.visibleCanvasIds = visibleNodes
        }
        
        return visibleNodes
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
