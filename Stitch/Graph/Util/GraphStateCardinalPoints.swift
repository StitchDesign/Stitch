//
//  GraphStateCardinalPoints.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/17/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Easternmost, Northernmost etc. nodes are relative to traversal level.
// eg top level might have nodes, but a currently focused group might not.
extension GraphState {

    // TODO: do we also need to check whether a given node is on-screen or not?
    // (Should not need to, since eg the eastern-most node will have to come on-screen before it can hit the screen's western border.)

    @MainActor
    func canvasItemsAtTraversalLevel(_ focusedGroupNodeId: NodeId?) -> CanvasItemViewModels {
        self.visibleNodesViewModel
            .getVisibleCanvasItems(at: focusedGroupNodeId )
    }

    // eastern-most node is node with greatest x-position
    @MainActor
    static func easternMostNode(_ focusedGroupNodeId: NodeId?,
                                canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        canvasItems
            .max { n, n2 in
                n.position.x < n2.position.x
            }
    }
    
    // Do we want the node's "position" or its cached-bounds origin ?
    @MainActor
    func westernMostNodeForBorderCheck(_ canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        GraphState.westernMostNode(self.groupNodeFocused, canvasItems: canvasItems)
    }
    
    @MainActor
    func easternMostNodeForBorderCheck(_ canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        GraphState.easternMostNode(self.groupNodeFocused, canvasItems: canvasItems)
    }
    
    // Do we want the node's "position" or its cached-bounds origin ?
    @MainActor
    func northernMostNodeForBorderCheck(_ canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        GraphState.northernMostNode(self.groupNodeFocused, canvasItems: canvasItems)
    }
    
    @MainActor
    func southernMostNodeForBorderCheck(_ canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        GraphState.southernMostNode(self.groupNodeFocused, canvasItems: canvasItems)
    }
    
    // western-most node is node with least x-position
    @MainActor
    static func westernMostNode(_ focusedGroupNodeId: NodeId?,
                                canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        canvasItems
            .max { n, n2 in
                n.position.x > n2.position.x
            }
    }

    // southern-most node is node with greatest y-position
    @MainActor
    static func southernMostNode(_ focusedGroupNodeId: NodeId?,
                                 canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        canvasItems
            .max { n, n2 in
                n.position.y < n2.position.y
            }
    }

    // northern-most node is node with least y-position
    @MainActor
    static func northernMostNode(_ focusedGroupNodeId: NodeId?,
                                 canvasItems: CanvasItemViewModels) -> CanvasItemViewModel? {
        canvasItems
            .max { n, n2 in
                n.position.y > n2.position.y
            }
    }
}
