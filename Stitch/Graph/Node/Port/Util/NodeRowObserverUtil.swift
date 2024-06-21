//
//  NodeRowObserverUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

// MARK: -- Extension methods that need some love

// TODO: we can't have a NodeRowObserver without also having a GraphDelegate (i.e. GraphState); can we pass down GraphDelegate to avoid the Optional unwrapping?
extension NodeRowObserver {
    
    @MainActor
    func getCanvasItemForNodeOnGraph() -> CanvasItemViewModel? {
        self.nodeDelegate?
            .graphDelegate?
            .getCanvasItem(.node(self.id.nodeId))
    }
    
    @MainActor
    func getIsNodeSelected() -> Bool {
        
        let isSelectedLayerInputOnGraph = canvasUIData?.isSelected
        let isSelectedNodeOnGraph = self.nodeDelegate?.graphDelegate?.getCanvasItem(.node(self.id.nodeId))?.isSelected
        
        return isSelectedLayerInputOnGraph ?? isSelectedNodeOnGraph ?? false
    }
    
    //
    @MainActor
    func getIsNodeSelectedForPortColor() -> Bool {
        
        /*
         If this is row is for a splitter node in a group node, and the group node is selected, then consider this splitter selected as well.
         NOTE: this is only for port/edge-color purposes; do not use this for e.g. node movement etc.
         
         TODO: we only care about splitterType = .input or .output; add `splitterType` to `NodeDelegate`.
         */
        if self.nodeKind == .patch(.splitter),
           // Only for splitter patch nodes
           let parentId = self.nodeDelegate?.parentGroupNodeId,
           self.nodeDelegate?.graphDelegate?.getNodeViewModel(parentId)?.patchNode?.isSelected ?? false {
            return true
        } else {
            return self.getIsNodeSelected()
        }
    }
    
    @MainActor
    func getIsConnectedToASelectedNode() -> Bool {
        if let graph = self.nodeDelegate?.graphDelegate {
            return graph.isConnectedToASelectedNode(at: self)
        } else {
            log("NodeRowObserver: getIsConnectedToASelectedNode: could not retrieve delegates")
            return false
        }
    }
    
    @MainActor
    func getHasSelectedEdge() -> Bool {
        if let graph =  self.nodeDelegate?.graphDelegate {
            return graph.hasSelectedEdge(at: self)
        } else {
            log("NodeRowObserver: getHasSelectedEdge: could not retrieve delegates")
            return false
        }
    }

    @MainActor
    func getEdgeDrawingObserver() -> EdgeDrawingObserver {
        if let drawing = self.nodeDelegate?.graphDelegate?.edgeDrawingObserver {
            return drawing
        } else {
            log("NodeRowObserver: getEdgeDrawingObserver: could not retrieve delegates")
            return .init()
        }
    }
}
