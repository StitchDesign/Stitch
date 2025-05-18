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

// TODO: do we want different 'near-ness' for detecting eligible canvas inputs vs eligible inspector inputs/fields ?
/// Are these two points within NEARNESS_ALLOWANCE of each other?
func areNear(_ inputCenter: CGPoint,
             _ cursorCenter: CGPoint,
             isInspectorInputOrFieldDetection: Bool,
             nearnessAllowance: CGFloat = NODE_ROW_HEIGHT) -> Bool {


    // log("areNear: inputCenter: \(inputCenter)")
    // log("areNear: cursorCenter: \(cursorCenter)")

    let range = CGSize(width: nearnessAllowance * 3,
                       // Inspector rows have a little more space between them
                       height: nearnessAllowance * (isInspectorInputOrFieldDetection ? 2 : 1))

    // shift inward slightly
    let box1 = CGRect.init(
        origin: .init(x: inputCenter.x + nearnessAllowance,
                      y: inputCenter.y),
        size: range)

    // TODO: maybe better to expand the cursor's location ?
    let box2 = CGRect.init(origin: cursorCenter,
                           size: range)

    // log("areNear: box1: \(box1)")
    // log("areNear: box2: \(box2)")

    let k = isIntersecting(box1, box2)
    // log("areNear: k: \(k)")
    return k
}


extension GraphState {
    /*
     In certain cases we won't find an eligible-input:
     - graph contains a single node
     - cursor position is too far from other inputs,
     - ... etc.
     */
    
    // fka `findEligibleInput`
    @MainActor
    func findEligibleCanvasInput(
        // The location of the user's output/input-dragged gesture
        cursorLocation: CGPoint,
        
        // Which node is this cursor-drawn-edge extended from?
        // Never create an edge from an output to an input on the very same node.
        cursorNodeId: CanvasItemId
    ) {
        
        let canvasItemsAtThisTraversalLevel = self
            .getCanvasItemsAtTraversalLevel(groupNodeFocused: documentDelegate?.groupNodeFocused?.groupNodeId)
        
        let eligibleInputs = canvasItemsAtThisTraversalLevel
            .flatMap { canvasItem -> [InputNodeRowViewModel] in
                canvasItem.inputViewModels
            }
        
        var nearestInputs = [InputNodeRowViewModel]()
        
        // Only look at pref-dict inputs' which are on this level
        for inputViewModel in eligibleInputs {
            guard let inputCenter = inputViewModel.portUIViewModel.anchorPoint else {
                continue
            }
  
            if areNear(inputCenter,
                       cursorLocation,
                       isInspectorInputOrFieldDetection: false)
                // i.e. don't create a connection to the output's node's own input!
                && inputViewModel.canvasItemDelegate?.id != cursorNodeId {
                nearestInputs.append(inputViewModel)
            }
        }
        
        let hadEligibleCanvasInput = self.edgeDrawingObserver.nearestEligibleEdgeDestination?.getCanvasInput.isDefined ?? false
        
        if nearestInputs.isEmpty,
           hadEligibleCanvasInput {
            log("findEligibleCanvasInput: wiping nearestEligibleEdgeDestination")
            self.edgeDrawingObserver.nearestEligibleEdgeDestination = nil
        } else if let nearestInput = nearestInputs.last {
            // While dragging cursor from an output/input,
            // we've detected that we're over an eligible input
            // to which we could create a connection.
            log("findEligibleCanvasInput: found nearestEligibleEdgeDestination: \(nearestInput)")
            self.edgeDrawingObserver.nearestEligibleEdgeDestination = .canvasInput(nearestInput)
        }
        
        // After we've set or wiped the nearestEligible input,
        // *animate* the port color change:
        withAnimation(.linear(duration: DrawnEdge.ANIMATION_DURATION)) {
            if let drawingGesture = self.edgeDrawingObserver.drawingGesture,
               let outputObserver = self.getOutputRowObserver(drawingGesture.outputId.asNodeIOCoordinate),
               let canvasItemId = drawingGesture.outputId.graphItemType.getCanvasItemId,
               let outputRowViewModel = self.getOutputRowViewModel(for: drawingGesture.outputId) {
                outputRowViewModel.portUIViewModel.updatePortColor(
                    canvasItemId: canvasItemId,
                    hasEdge: outputObserver.hasEdge,
                    hasLoop: outputObserver.hasLoopedValues,
                    selectedEdges: self.selectedEdges,
                    selectedCanvasItems: self.selectedCanvasItems,
                    drawingObserver: self.edgeDrawingObserver)
            }
        }
    }
    
    @MainActor
    func findEligibleInspectorInputOrField(drawingObserver: EdgeDrawingObserver,
                                           drawingGesture: OutputDragGesture,
                                           geometry: GeometryProxy,
                                           preferences: [EdgeDraggedToInspector: Anchor<CGRect>]) {
                
        var nearestInspectorInputs = [LayerInputType]()
        
        for preference in preferences {
            switch preference.key {
            case .inspectorInputOrField(let layerInputType):
                // Note: `areNear` *already* expands the 'hit area'
                if areNear(geometry[preference.value].mid,
                           drawingGesture.cursorLocationInGlobalCoordinateSpace,
                           isInspectorInputOrFieldDetection: true) {
                    
                    // log("findEligibleInspectorFieldOrRow: WAS NEAR: layerInputType: \(layerInputType)")
                    nearestInspectorInputs.append(layerInputType)
                }
                 
            case .draggedOutput:
                continue
            }
        } // for preference in ...
        
        let hadEligibleInspectorInputOrField = drawingObserver.nearestEligibleEdgeDestination?.getInspectorInputOrField.isDefined ?? false
        
        if nearestInspectorInputs.isEmpty,
           hadEligibleInspectorInputOrField {
            // log("findEligibleInspectorFieldOrRow: NO inspector inputs/fields")
            drawingObserver.nearestEligibleEdgeDestination = nil
        } else if let nearestInspectorInput = nearestInspectorInputs.last {
            // log("findEligibleInspectorFieldOrRow: found inspector input/field: \(nearestInspectorInput)")
            drawingObserver.nearestEligibleEdgeDestination = .inspectorInputOrField(nearestInspectorInput)
        }
        
        // After we've set or wiped the nearestEligible input,
        // *animate* the port color change:
        withAnimation(.linear(duration: DrawnEdge.ANIMATION_DURATION)) {
            self
                .getOutputRowObserver(drawingGesture.outputId.asNodeIOCoordinate)?
                .updateRowViewModelsPortColor(selectedEdges: self.selectedEdges,
                                              selectedCanvasItems: self.selectedCanvasItems,
                                              drawingObserver: drawingObserver)
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
