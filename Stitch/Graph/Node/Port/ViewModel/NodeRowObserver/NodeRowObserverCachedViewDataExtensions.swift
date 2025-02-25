//
//  NodeRowObserverCachedViewDataExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: derived/cached data: PortViewData, ActiveValue, PortColor

extension NodeRowViewModel {
    /// Gets node ID for currently visible node. Covers edge cause where group nodes use splitter nodes,
    /// which save a differnt node ID.
    @MainActor
    func visibleNodeIds(_ graph: GraphState) -> Set<CanvasItemId> {
        guard let nodeDelegate = self.nodeDelegate else {
            return []
        }
        
        let canvasItems = nodeDelegate.getAllCanvasObservers()
        
        return canvasItems.compactMap { canvasItem in
            guard canvasItem.isVisibleInFrame(graph.visibleCanvasIds) else {
                return nil
            }
            
            // We use the group node ID only if it isn't in focus
            if nodeDelegate.splitterType == .input &&
                graph.groupNodeFocused != canvasItem.parentGroupNodeId,
               let parentNodeId = canvasItem.parentGroupNodeId,
               let parentNode = graph.getNodeViewModel(parentNodeId),
               let parentCanvasItem = parentNode.patchCanvasItem {
                return parentCanvasItem.id
            }
            
            return canvasItem.id
        }
        .toSet
    }
   
   @MainActor
   func updateConnectedCanvasItems() {
       self.connectedCanvasItems = self.getConnectedCanvasItems()
       
       // Update port color data
       self.updatePortColor()
   }
   
   /// Nodes connected via edge.
   @MainActor
   private func getConnectedCanvasItems() -> Set<CanvasItemId> {
       guard let canvasIds = self.rowDelegate?.nodeDelegate?
        .getAllCanvasObservers()
        .map({ canvasItem in
            canvasItem.id
        }).toSet else {
           // Valid nil case for insert node menu
           return .init()
       }
       
       // Must get port UI data. Helpers below will get group or splitter data depending on focused group
       let connectedCanvasIds = self.findConnectedCanvasItems()
       return canvasIds.union(connectedCanvasIds)
   }
}

