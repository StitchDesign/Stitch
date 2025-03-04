//
//  EdgeEditingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/24.
//

import StitchSchemaKit
import SwiftUI
import NonEmpty

typealias PossibleEdgeId = InputPortViewData

struct PossibleEdge: Hashable {
    var edge: PortEdgeUI

    /*
     Whether this possible edge is "committed";
     controls whether this edge is added to / removed from graph schema,
     and, for animation purposes, the PossibleEdgeView's `to`.
     */
    var isCommitted: Bool // = false
}

extension PossibleEdge {
    var id: InputPortViewData {
        edge.id
    }
}

typealias PossibleEdgeSet = Set<PossibleEdge>

typealias EligibleEasternNodes = NonEmptyArray<CanvasItemId>

struct EdgeEditingState {
    
    static let defaultNearbyCanvasItemIndex = 0
    
    // currently hovered-over output
    var originOutput: OutputPortViewData
    
    // the node that is east of, and the shortest distance from, the origin node
    //    var nearbyCanvasItem: CanvasItemId
    var nearbyCanvasItem: CanvasItemId {
        self.eastNodesFromClosestToFarthest[safeIndex: self.nearbyCanvasItemIndex] ?? self.eastNodesFromClosestToFarthest.first
    }
    
    // Canvas items east of the hovered output,
    // with closest closest canvas item at index = 0
    var eastNodesFromClosestToFarthest: EligibleEasternNodes

    // Modified by `canvasItemIndexChanged`
    var nearbyCanvasItemIndex: Int // = Self.defaultNearbyCanvasItemIndex
        
    var possibleEdges: PossibleEdgeSet

    /// Are we showing the edge-edit mode labels in front of inputs?
    /// True just if we have hovered the minimum duration.
    var labelsShown: Bool = false

    // Animation-related data

    /*
     Possible edge id found in set = whether the edge is at all visible or not.

     True whenever edge is extended or animating (extending or withdrawing).
     False whenever edge has completed withdrawing.

     Not the same thing as the edge's isCommitted, since e.g. de-committing an edge sets is isCommitted = false
     but we still need to show the edge until the withdrawal animation completes.
     */
    var shownIds: Set<InputPortViewData> = .init()

    /*
     Possible edge id found in set = edge is currently animating (extending or withdrawing).

     We ignore key presses for edges actively animating;
     prevents the key spamming that gives non-deterministic results with `withAnimation`'s `completion` handler.
     */
    var animationInProgressIds: Set<PossibleEdgeId> = .init()

    func isShown(_ possibleEdgeId: PossibleEdgeId) -> Bool {
        shownIds.contains(possibleEdgeId)
    }

    func isAnimating(_ possibleEdgeId: PossibleEdgeId) -> Bool {
        animationInProgressIds.contains(possibleEdgeId)
    }
    
}

extension EdgeEditingState {
    
    // TODO: make EdgeEditingState an @Observable if perf problems encountered; but perf should be fine given that this is done via a user-button press
    @MainActor
    func canvasItemIndexChanged(edgeEditState: EdgeEditingState,
                                graph: GraphState,
                                wasIncremented: Bool,
                                groupNodeFocused: NodeId?) -> Self {
        
        var edgeEditState = edgeEditState._indexChanged(
            edgeEditState: edgeEditState,
            wasIncremented: wasIncremented)
                
        // Immediately show labels
        edgeEditState.labelsShown = true
        
        // Update possible edges etc.
        guard let newNearbyNode = graph.getCanvasItem(edgeEditState.nearbyCanvasItem) else {
            fatalErrorIfDebug()
            return edgeEditState
        }
        
        let (alreadyShownEdges,
             possibleEdges) = graph.getShownAndPossibleEdges(
            nearbyNode: newNearbyNode,
            outputCoordinate: edgeEditState.originOutput,
            groupNodeFocused: groupNodeFocused)
        
        edgeEditState.shownIds = alreadyShownEdges
        edgeEditState.possibleEdges = possibleEdges
        
        return edgeEditState
    }
    
    private func _indexChanged(edgeEditState: EdgeEditingState,
                               wasIncremented: Bool) -> Self {
        
        var edgeEditState = edgeEditState
        
        let eastNodeCount = edgeEditState.eastNodesFromClosestToFarthest.count
        
        if wasIncremented {
            if (edgeEditState.nearbyCanvasItemIndex + 1) >= eastNodeCount {
                // If we incremented past the end, jump back to the start.
                edgeEditState.nearbyCanvasItemIndex = 0
            } else {
                edgeEditState.nearbyCanvasItemIndex += 1
            }
        } else {
            if (edgeEditState.nearbyCanvasItemIndex - 1) < 0 {
                edgeEditState.nearbyCanvasItemIndex = eastNodeCount - 1
            } else {
                edgeEditState.nearbyCanvasItemIndex -= 1
            }
        }
                
        return edgeEditState
    }
}
