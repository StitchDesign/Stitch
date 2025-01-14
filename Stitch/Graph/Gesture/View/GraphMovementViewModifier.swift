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
                log("currentNodePage.localPosition: \(currentNodePage.localPosition)")
                
                // curentNodePage local position is default rather than persisted local position when graph first opened
                self.graphMovement.localPosition = currentNodePage.localPosition
                self.graphMovement.localPreviousPosition = currentNodePage.localPosition
                
                self.graphMovement.zoomData.current = currentNodePage.zoomData.current
                self.graphMovement.zoomData.final = currentNodePage.zoomData.final
                
                self.graph.updateVisibleNodes()
            }
            .onChange(of: graphMovement.localPosition) { _, newValue in
                currentNodePage.localPosition = graphMovement.localPosition
                
                self.graph.updateVisibleNodes()
            }
            .onChange(of: graphMovement.zoomData.current) { _, newValue in
                currentNodePage.zoomData.current = graphMovement.zoomData.current
            }
            .onChange(of: graphMovement.zoomData.final) { _, newValue in
                currentNodePage.zoomData.final = graphMovement.zoomData.final
                
                self.graph.updateVisibleNodes()
            }
    }
}
    
extension GraphState {
    /// Accomplishes the following tasks:
    /// 1. Determines which nodes are visible.
    /// 2. Determines which nodes are selected from the selection box, if applicable.
    @MainActor
    func updateVisibleNodes() {
        
        let zoom = self.graphMovement.zoomData.zoom
        
        // How much that content is offset from the UIScrollView's top-left corner;
        // can never be negative.
        let originOffset = self.graphMovement.localPosition
        
        let scaledOffset = CGPoint(x: originOffset.x / zoom,
                                   y: originOffset.y / zoom)

        let viewPortSize = self.graphUI.frame.size
                
        let scaledSize = CGSize(width: viewPortSize.width * 1/zoom,
                                height: viewPortSize.height * 1/zoom)
        
        let viewFrame = CGRect.init(origin: scaledOffset,
                                    size: scaledSize)
                
        // Determine nodes to make visible--use cache in case nodes exited viewframe
        var newVisibleNodes = Set<CanvasItemId>()
        
        for cachedSubviewData in self.visibleNodesViewModel.infiniteCanvasCache {
            let id = cachedSubviewData.key
            let cachedBounds = cachedSubviewData.value
            
            let isVisibleInFrame = viewFrame.intersects(cachedBounds)
            
            if isVisibleInFrame {
                newVisibleNodes.insert(id)
            }
        }
        
        if self.visibleNodesViewModel.visibleCanvasIds != newVisibleNodes {
            self.visibleNodesViewModel.visibleCanvasIds = newVisibleNodes
        }
    }    
}
