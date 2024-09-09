//
//  MouseInteractionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/19/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func mouseInteractionNode(id: NodeId,
                          position: CGSize = .zero,
                          zIndex: Double = 0,
                          interactionId: PortValue = interactionIdDefault) -> PatchNode {

    let inputs = fakeInputs(id: id)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Down", [boolDefaultFalse]), // 0
        ("Position", [.position(.zero)]), // 1
        ("Velocity", [.position(.zero)]) // 2
    )

    // Don't need any internal state
    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .mouse,
        inputs: inputs,
        outputs: outputs)
}

struct MouseNodeOutputLocations {
    static let leftClick = 0
    static let position = 1
    static let velocity = 2
}

let MOUSE_NODE_DEFAULT_OUTPUTS: PortValuesList = [
    [.bool(false)],
    [.position(.zero)],
    [.position(.zero)]
]

extension GraphState {
    var mouseNodes: IdSet {
        self.nodes.values
            .filter { $0.patch == .mouse }
            .map { $0.id }
            .toSet
    }
}

func mouseEval(inputs: PortValuesList,
               outputs: PortValuesList) -> PortValuesList {
    // If first input is not bool, then we've called this node eval after
    if outputs.first?.first?.getBool == nil {
        return MOUSE_NODE_DEFAULT_OUTPUTS
    }
    
    // Else it's a noop -- just reuse the values from LayerHovered and LayerHoverEnded
    return outputs
}

