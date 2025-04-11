//
//  GraphMovementViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/4/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit
    
extension StitchDocumentViewModel {
    
    // fka `GraphState.updateVisibleNodes`
    @MainActor
    func updateVisibleCanvasItems() {
        
        let document = self
        
        // Really only makes sense to do on the visible graph
        let graph = document.visibleGraph
        
        /*
         Note: `updateVisibleNodes` is called when the UIScrollView jumps to the graph's absolute-center upon project first open (`GraphScrollUpdated` dispatched from `scrollViewDidScroll` method).
         However, at that point the canvas-cache has not yet been populated, so the `newVisibleNodes = .init()` was not being populated,
         thus incorrectly negating "treat all nodes as visible upon graph eval at graph opening" effect we want at the
         
         TODO: how to distinguish between a canvas-cache that has *never* been populated, vs. one that is empty bea vs. one that is empty because there are no longer any nodes at that traversal level ?
         
         TODO: alternatively, could use a flag in `UIScrollView` such that `GraphScrollUpdated` does not trigger `updateVisibleNodes` when first jumping to graph center upon project open ?
         */
        if self.graph.visibleNodesViewModel.infiniteCanvasCache.isEmpty
//           // TODO: perf impact of constantly checking canvas-items-at-this-traversal-level ?
//           , !self.canvasItemsAtTraversalLevel(document.groupNodeFocused).isEmpty
        {
            return
        }
        
        let originalVisibleCanvasItems = graph.visibleNodesViewModel.visibleCanvasIds
        
        // Determine nodes to make visible--use cache in case nodes exited viewframe
        var newVisibleCanvasItems = self.determineVisibleCanvasItems(
            zoom: document.graphMovement.zoomData,
            localPosition: document.graphMovement.localPosition,
            frame: document.frame,
            cache: graph.visibleNodesViewModel.infiniteCanvasCache)
        
        if originalVisibleCanvasItems != newVisibleCanvasItems {
            graph.visibleNodesViewModel.visibleCanvasIds = newVisibleCanvasItems
            
            // Update the cached-UI-data (e.g. fieldObservers) of the canvas items that just became visible
            let becameVisible = newVisibleCanvasItems.subtracting(originalVisibleCanvasItems)
            for canvasItemId in becameVisible {
                graph.updateCanvasItemFields(canvasItemId: canvasItemId,
                                             activeIndex: document.activeIndex)
            }
        }
    }
    
    @MainActor
    private func determineVisibleCanvasItems(zoom: CGFloat,
                                             localPosition: CGPoint,
                                             frame: CGRect,
                                             cache: InfiniteCanvas.Cache) -> CanvasItemIdSet {
        
        // How much that content is offset from the UIScrollView's top-left corner;
        // can never be negative.
        let originOffset = localPosition
        
        let scaledOffset = CGPoint(x: originOffset.x / zoom,
                                   y: originOffset.y / zoom)

        let viewPortSize = frame.size
                
        let scaledSize = CGSize(width: viewPortSize.width * 1/zoom,
                                height: viewPortSize.height * 1/zoom)
        
        let viewFrame = CGRect.init(origin: scaledOffset,
                                    size: scaledSize)
                
//        let originalVisibleNodes = graph.visibleNodesViewModel.visibleCanvasIds
        
        // Determine nodes to make visible--use cache in case nodes exited viewframe
        var newVisibleNodes = Set<CanvasItemId>()
        
        for cachedSubviewData in cache {
            
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
                    newVisibleNodes.formUnion(graph.visibleNodesViewModel.getSplitterInputRowObserverIds(for: potentialGroupNodeId))
                    newVisibleNodes.formUnion(graph.visibleNodesViewModel.getSplitterOutputRowObserverIds(for: potentialGroupNodeId))
                }
            }
//            else {
//                // log("updateVisibleNodes: NOT visible: \(id), cachedBounds: \(cachedBounds)")
//            }
        } // for cachedSubviewData
        
        return newVisibleNodes
    }
}

extension NodeRowViewModel {
    var nodeIOCoordinate: NodeIOCoordinate {
        self.id.asNodeIOCoordinate
    }
}
