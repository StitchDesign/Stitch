//
//  EdgeHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/5/24.
//

import SwiftUI
import StitchSchemaKit
import StitchEngine

typealias Connections = GraphTopologicalData<NodeViewModel>.Connections

let LOOP_EDGE_COLOR = Color.blue
let HIGHLIGHTED_LOOP_EDGE_COLOR: Color = .cyan

let MINIMUM_FORWARD_FACING_NODE_DISTANCE = 40.0

func xDistance(_ from: CGPoint,
               _ to: CGPoint) -> CGFloat {
    abs(from.x - to.x)
}

func destinationIsBelow(_ from: CGPoint,
                        _ to: CGPoint) -> Bool {
    to.y > from.y
}

// Note: used for backward edge legacy cases
func yDistance(_ from: CGPoint,
               _ to: CGPoint) -> CGFloat {
    abs(from.y - to.y)
}

// Are these two points within NEARNESS_ALLOWANCE of each other?
func areNear(_ inputCenter: CGPoint, _ cursorCenter: CGPoint) -> Bool {

    let NEARNESS_ALLOWANCE: CGFloat = NODE_ROW_HEIGHT

    //    log("areNear: inputCenter: \(inputCenter)")
    //    log("areNear: cursorCenter: \(cursorCenter)")

    let range = CGSize(width: NEARNESS_ALLOWANCE * 3,
                       height: NEARNESS_ALLOWANCE)

    // shift inward slightly
    let box1 = CGRect.init(
        origin: .init(x: inputCenter.x + NEARNESS_ALLOWANCE,
                      y: inputCenter.y),
        size: range)

    let box2 = CGRect.init(origin: cursorCenter,
                           size: range)

    //    log("areNear: box1: \(box1)")
    //    log("areNear: box2: \(box2)")

    let k = isIntersecting(box1, box2)
    //    log("areNear: k: \(k)")
    return k
}


extension GraphState {
    /*
     In certain cases we won't find an eligible-input:
     - graph contains a single node
     - cursor position is too far from other inputs,
     - ... etc.
     */
    @MainActor
    func findEligibleInput(
        // The location of the user's output/input-dragged gesture
        cursorLocation: CGPoint,
        
        // Which node is this cursor-drawn-edge extended from?
        // Never create an edge from an output to an input on the very same node.
        cursorNodeId: CanvasItemId) {
        
        var nearestInputs = [InputNodeRowViewModel]()
            
            let canvasItemsAtThisTraversalLevel = self
                .getCanvasItemsAtTraversalLevel(groupNodeFocused: documentDelegate?.groupNodeFocused?.groupNodeId)
            
            let eligibleInputs = canvasItemsAtThisTraversalLevel
                .flatMap { canvasItem -> [InputNodeRowViewModel] in
                    canvasItem.inputViewModels
                }
        
        // Only look at pref-dict inputs' which are on this level
        for inputViewModel in eligibleInputs {
            guard let inputCenter = inputViewModel.anchorPoint else {
                continue
            }
            
            if areNear(inputCenter, cursorLocation)
                && inputViewModel.canvasItemDelegate?.id != cursorNodeId {
                nearestInputs.append(inputViewModel)
            }
        }
        
        if nearestInputs.isEmpty {
            dispatch(EligibleInputReset())
        } else if let nearestInput = nearestInputs.last {
            // While dragging cursor from an output/input,
            // we've detected that we're over an eligible input
            // to which we could create a connection.
            self.edgeDrawingObserver.nearestEligibleInput = nearestInput
        }
    }
    
    /// Removes edges which root from some output coordinate.
    @MainActor
    func removeConnections(from outputCoordinate: NodeIOCoordinate) {
        guard let connectedInputs = self.connections.get(outputCoordinate) else {
            return
        }

        connectedInputs.forEach { inputs in
            guard let inputObserver = self.getInputObserver(coordinate: inputs),
                  let inputObserverNode = self.getNode(inputObserver.id.nodeId) else {
                return
            }
            
            inputObserver.removeUpstreamConnection(node: inputObserverNode)
        }
    }
}
