//
//  EdgeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/21/23.
//

import SwiftUI
import StitchSchemaKit

//let SELECTED_EDGE_Z_INDEX_BOOST = 1.0
let SELECTED_EDGE_Z_INDEX_BOOST = 99999999.0

struct EdgeView: View {
    
    @Environment(\.appTheme) var theme
    
    // TODO: optionally pass in the edge for actively-drawn cases
    let edge: PortEdgeUI
    
    let pointFrom: CGPoint
    let pointTo: CGPoint
    let color: Color
    let isActivelyDragged: Bool
    
    // both derived from first edge ?
    let firstFrom: CGPoint
    let firstTo: CGPoint
    
    let lastFrom: CGPoint
    let lastTo: CGPoint
    
    // Used to calculate largest y distance
    // Optional for edge dragging from output
    // TODO: are these really still optional for actively-dragged edge? or is it just "edge dragged from output"?
    var firstFromWithEdge: CGFloat?
    var lastFromWithEdge: CGFloat?
    var firstToWithEdge: CGFloat?
    var lastToWithEdge: CGFloat?
    
    // should just be lastEdge.portId + 1
    let totalOutputs: Int
    
    let edgeAnimationEnabled: Bool
    
    let edgeScaleEffect: CGFloat

    var largestYDistance: CGFloat {        
        guard let firstFromWithEdge = firstFromWithEdge,
              let lastFromWithEdge = lastFromWithEdge,
              let firstToWithEdge = firstToWithEdge,
              let lastToWithEdge = lastToWithEdge else {
            // Hits on edge drag when no eligible input found yet
            return 0
        }
        
        let destinationBelow = pointTo.y > pointFrom.y
        
        let largestYDistance = destinationBelow ? (lastToWithEdge - firstFromWithEdge) : (lastFromWithEdge - firstToWithEdge)
        return largestYDistance
    }

    /*
     z-index for an edge is determined by:
     - is edge selected or not
     - origin node's own z-index
     - the output's index

     Note:  all non-actively-drawn, non-selected edges from a single output will have the same color, so it's all right for them to have same z-index.
     If an edge from an output is actively drawn or selected, then it will be above all the other edges from that same output anyway.
     */

    var body: some View {
        DrawnEdge(from: pointFrom,
                  to: pointTo,
                  color: color,
                  isActivelyDragged: isActivelyDragged,
                  firstFrom: firstFrom,
                  firstTo: firstTo,
                  lastFrom: lastFrom,
                  fromIndex: edge.fromIndex,
                  totalOutputs: totalOutputs,
                  largestYDistance: largestYDistance,
                  edgeAnimationEnabled: edgeAnimationEnabled,
                  edgeScaleEffect: edgeScaleEffect)
        .onTapGesture {
            dispatch(EdgeTapped(edge: edge))
        }
    }
}
