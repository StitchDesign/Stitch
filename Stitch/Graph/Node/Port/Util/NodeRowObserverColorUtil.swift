//
//  NodeRowObserverColorUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

extension PortColor {
    /*
     `isSelected: Bool`: Is the port "selected"? Depending on context, could mean that node is selected, OR edge is selected, OR edge is actively drawn but has eligible-input etc.
     
     `hasLoop: Bool`: Does the port have a loop?
     
     `hasEdge: Bool`: Does the port have an edge?
     */
    init(isSelected: Bool, hasEdge: Bool, hasLoop: Bool) {
        if hasLoop && hasEdge && isSelected {
            self = .highlightedLoopEdge
        } else if hasEdge && isSelected {
            self = .highlightedEdge
        } else if hasLoop && hasEdge {
            self = .loopEdge
        } else if hasEdge {
            self = .edge
        } else {
            self = .noEdge
        }
    }
}

extension NodeRowObserver {
    // TODO: don't we have an abstract helper here for ANY property?
    // e.g. `self.portColor.setOnChange(newPortColor)`
    func setPortColorIfChanged(_ newPortColor: PortColor) {
        if newPortColor != self.portColor {
            self.portColor = newPortColor
        }
    }
}

/*
 When a node is selected or deselected, for each of its inputs/outptus we must re-derive the color for:
 
 1. the input/output itself
 2. if input: the upstream output, if there is one
 3. if output: the downstream inputs, if there are any
 
 ASSUMES NODE VIEW MODEL'S `isSelected` HAS BEEN UPDATED.
 */
@MainActor
func updatePortColorDataUponNodeSelection(node: NodeDelegate,
                                          graphState: GraphDelegate) {
    
    updatePortColorDataUponNodeSelection(
        inputs: node.inputRowObservers(),
        outputs: node.outputRowObservers(),
        graphState: graphState)
}

@MainActor
func updatePortColorDataUponNodeSelection(inputs: NodeRowObservers,
                                          outputs: NodeRowObservers,
                                          graphState: GraphDelegate) {
    inputs.forEach { input in
        updateColorOfInputAndUpstreamOutput(input: input,
                                            graphState: graphState)
    }
    
    outputs.forEach { output in
        updateColorOfOutputAndDownstreamInputs(output: output,
                                               graphState: graphState)
    }
}

@MainActor
func updateInputColor(input: NodeRowObserver,
                      graphState: GraphDelegate) {
    
    let newInputColor = getInputColor(
        isNodeSelected: input.getIsNodeSelectedForPortColor(),
        hasEdge: input.hasEdge,
        hasLoop: input.hasLoopedValues,
        isConnectedToASelectedNode: input.getIsConnectedToASelectedNode(),
        isEdgeSelected: graphState.hasSelectedEdge(at: input))
    
    input.setPortColorIfChanged(newInputColor)
}

@MainActor
func updateColorOfInputAndUpstreamOutput(input: NodeRowObserver,
                                         // Note: can use the more restricted type `GraphDelegate` instead of gigantic `GraphState`
                                         graphState: GraphDelegate) {
    
    updateInputColor(input: input, graphState: graphState)
        
    // Update upstream-output
    if let output = input.upstreamOutputObserver {
        updateOutputColor(output: output, 
                          graphState: graphState)
    }
}

@MainActor
func updateOutputColor(output: NodeRowObserver,
                       graphState: GraphDelegate) {
    
    let newOutputColor = getOutputColor(
        outputId: output.id,
        isNodeSelected: output.getIsNodeSelectedForPortColor(),
        hasEdge: output.hasEdge,
        hasLoop: output.hasLoopedValues,
        isConnectedToASelectedNode: output.getIsConnectedToASelectedNode(),
        isEdgeSelected: graphState.hasSelectedEdge(at: output),
        drawingObserver: graphState.edgeDrawingObserver)
    
    output.setPortColorIfChanged(newOutputColor)
}

@MainActor
func updateColorOfOutputAndDownstreamInputs(output: NodeRowObserver,
                                            graphState: GraphDelegate) {
    updateOutputColor(output: output, graphState: graphState)
    
    // Update downstream-inputs
    graphState.connections
        .get(output.id)?
        .compactMap { graphState.getInputObserver(coordinate: $0) }
        .forEach { downstreamInput in
            updateInputColor(input: downstreamInput, 
                             graphState: graphState)
        }
}


// Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
func getInputColor(isNodeSelected: Bool, // Is the input's parent node selected?
                   hasEdge: Bool, // Does the input have an edge?
                   hasLoop: Bool, // Does the input have a loop?
                   isConnectedToASelectedNode: Bool,
                   // Is this input's incoming edge 'selected'?
                   isEdgeSelected: Bool) -> PortColor {
    .init(isSelected: isNodeSelected || isConnectedToASelectedNode || isEdgeSelected,
          hasEdge: hasEdge,
          hasLoop: hasLoop)
}

@MainActor 
func getOutputColor(outputId: NodeIOCoordinate,
                    isNodeSelected: Bool, // Is the output's parent node selected?
                    hasEdge: Bool, // Does the output have an edge?
                    hasLoop: Bool, // Does the output have a loop?
                    isConnectedToASelectedNode: Bool,
                    isEdgeSelected: Bool, // Does this output have at least one outgoing edge which is selected?
                    drawingObserver: EdgeDrawingObserver) -> PortColor {
            
    /*
     Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
     
     An actively-drawn edge's color is determined only by:
     1. "Do we have a loop?" (blue vs theme-color) and
     2. "Do we have an eligible input?" (highlight vs non-highlighted)
     */
    if let drawnEdge = drawingObserver.drawingGesture,
        drawnEdge.output.id == outputId {
        return PortColor(
            isSelected: drawingObserver.nearestEligibleInput.isDefined,
//                     hasEdge: true, // TODO: should be able to
                     hasEdge: hasEdge,
                     hasLoop: hasLoop)
    }
    
    
    // Otherwise, common port color logic applies:
    else {
        return PortColor(isSelected: isNodeSelected || isConnectedToASelectedNode || isEdgeSelected,
                     hasEdge: hasEdge,
                     hasLoop: hasLoop)
    }
}
