//
//  NodeRowObserverUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

// MARK: -- Extension methods that need some love

// TODO: we can't have a NodeRowObserver without also having a GraphState (i.e. GraphState); can we pass down GraphState to avoid the Optional unwrapping?
extension NodeRowViewModel {
    @MainActor
    var graphDelegate: GraphState? {
        self.nodeDelegate?.graphDelegate
    }
    
    @MainActor
    var nodeKind: NodeKind {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return .patch(.splitter)
        }
        
        return node.kind
    }
 
    @MainActor
    func isConnectedToASelectedCanvasItem(_ selectedCanvasItems: CanvasItemIdSet) -> Bool {
        for connectedCanvasItemId in self.connectedCanvasItems {
            if selectedCanvasItems.contains(connectedCanvasItemId) {
                // Found connected canvas item that is selected
                return true
            }
        }
        return false
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
