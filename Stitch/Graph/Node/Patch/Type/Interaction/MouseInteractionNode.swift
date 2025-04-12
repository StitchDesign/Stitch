//
//  MouseInteractionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/19/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct MouseInteractNode: PatchNodeDefinition {
    static let patch = Patch.mouse
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [], // Actually has NO inputs
            outputs: [
                .init(
                    label: "Down",
                    type: .bool
                ),
                .init(
                    label: LayerInputPort.position.label(),
                    type: .position
                ),
                .init(
                    label: "Velocity",
                    type: .position
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MouseNodeState()
    }
}

final class MouseNodeState: NodeEphemeralObservable {
    var isDown: Bool = false
    var position: CGPoint = .zero
    var velocity: CGPoint = .zero
    
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.isDown = false
        self.position = .zero
        self.velocity = .zero
    }
}

let MOUSE_NODE_DEFAULT_OUTPUTS: PortValuesList = [
    [.bool(false)],
    [.position(.zero)],
    [.position(.zero)]
]

extension GraphState {
    @MainActor
    var mouseNodes: IdSet {
        self.nodes.values
            .filter { $0.patch == .mouse }
            .map { $0.id }
            .toSet
    }
}

@MainActor
func mouseEval(node: PatchNode) -> EvalResult {
    
    guard let mouseNodeState = node.ephemeralObservers?.first as? MouseNodeState else {
        return .init(outputsValues: MOUSE_NODE_DEFAULT_OUTPUTS)
    }
    
    return .init(outputsValues: [
        [.bool(mouseNodeState.isDown)],
        [.position(mouseNodeState.position)],
        [.position(mouseNodeState.velocity)]
    ])
}
