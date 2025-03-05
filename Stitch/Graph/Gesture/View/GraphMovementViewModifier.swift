//
//  GraphMovementViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/4/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit
    
extension GraphState {
    /// Accomplishes the following tasks:
    /// 1. Determines which nodes are visible.
    /// 2. Determines which nodes are selected from the selection box, if applicable.
    @MainActor
    func updateVisibleNodes() {
        
        guard let document = self.documentDelegate else { return }
        
        let zoom = self.graphMovement.zoomData
        
        // How much that content is offset from the UIScrollView's top-left corner;
        // can never be negative.
        let originOffset = self.graphMovement.localPosition
        
        let scaledOffset = CGPoint(x: originOffset.x / zoom,
                                   y: originOffset.y / zoom)

        let viewPortSize = document.frame.size
                
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
                
                /*
                 If a GroupNode is "visible on screen" (i.e. within the user's viewport),
                 then we should consider its underlying input- and output-splitters visible as well,
                 for the purposes of UI field updates.
                
                 Note: CanvasItemId.layerInput and CanvasItemId.layerOutput can never be a GroupNode,
                 but CanvasItemId.node could be a GroupNode.
                 */
                if let potentialGroupNodeId = id.nodeCase {
                    newVisibleNodes.formUnion(self.visibleNodesViewModel.getSplitterInputRowObserverIds(for: potentialGroupNodeId))
                    newVisibleNodes.formUnion(self.visibleNodesViewModel.getSplitterOutputRowObserverIds(for: potentialGroupNodeId))
                }
                
                // log("updateVisibleNodes: visible: \(id)")
            } else {
                // log("updateVisibleNodes: NOT visible: \(id), cachedBounds: \(cachedBounds)")
            }
        }
                        
        if self.visibleNodesViewModel.visibleCanvasIds != newVisibleNodes {
            self.visibleNodesViewModel.visibleCanvasIds = newVisibleNodes
        }
    }    
}
