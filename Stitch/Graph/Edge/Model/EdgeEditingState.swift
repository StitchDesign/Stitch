//
//  EdgeEditingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/24.
//

import StitchSchemaKit
import SwiftUI

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

struct EdgeEditingState {

    // currently hovered-over output
    var originOutput: OutputPortViewData

    // the node that is east of, and the shortest distance from, the origin node
    var nearbyNode: CanvasItemId

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
