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
        cursorNodeId: CanvasItemId,
        
        // Since deleted nodes are not removed from prefDict,
        // if we iterate through prefDict, we will potentially propose a deleted input.
        // So instead we iterate through VisibleNodes' inputs (i.e. inputs at this traversal level).
        eligibleInputCandidates: [InputNodeRowViewModel]) {
        
        var nearestInputs = [InputNodeRowViewModel]()
        
        // Only look at pref-dict inputs' which are on this level
        for inputViewModel in eligibleInputCandidates {
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
        } else {
            nearestInputs.last?.eligibleInputDetected(graphState: self)
        }
    }
    
    /// Removes edges which root from some output coordinate.
    @MainActor
    func removeConnections(from outputCoordinate: NodeIOCoordinate,
                           isNodeVisible: Bool,
                           activeIndex: ActiveIndex) {
        guard let connectedInputs = self.connections.get(outputCoordinate) else {
            return
        }

        connectedInputs.forEach { inputs in
            guard let inputObserver = self.getInputObserver(coordinate: inputs) else {
                return
            }
            
            inputObserver.removeUpstreamConnection(activeIndex: activeIndex,
                                                   isVisible: isNodeVisible)
        }
    }
}

// struct EdgeDrawingView_Previews: PreviewProvider {
//    static var previews: some View {
//        EdgeDrawingView()
//    }
// }
