//
//  PressInteractionPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PressInteractionNode: PatchNodeDefinition {
    static let patch = Patch.pressInteraction

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Enabled"
                ),
                // TODO: remove this input? (We rely on SwiftUI's double-tap timing). Requires a migration
                .init(
                    defaultValues: [.number(0.3)],
                    label: "Delay"
                )
            ],
            outputs: [
                .init(
                    label: "Down",
                    type: .bool
                ),
                .init(
                    label: "Tapped",
                    type: .pulse
                ),
                .init(
                    label: "Double Tapped",
                    type: .pulse
                ),
                .init(
                    label: LayerInputPort.position.label(),
                    type: .position
                ),
                .init(
                    label: "Velocity",
                    type: .size
                ),
                .init(
                    label: "Translation",
                    type: .size
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        PressInteractionNodeObserver()
    }
}

final class PressInteractionNodeObserver: NodeEphemeralObservable, Sendable {
    @MainActor var prevTapTime: TimeInterval?
    let actor: PressInteractionActor = .init()
}

extension PressInteractionNodeObserver {
    @MainActor
    func onPrototypeRestart() {
        self.prevTapTime = nil
    }
}

actor PressInteractionActor {
    func delayTap(delayValue: Double,
                  newTapTime: Double,
                  pressNode: NodeViewModel,
                  evalObserver: PressInteractionNodeObserver,
                  graph: GraphState,
                  loopIndex: Int,
                  createNewValues: @escaping @MainActor (TimeInterval) -> PortValues) async throws {
        let delayInNanoseconds = delayValue * Double(nanoSecondsInSecond)
        try await Task.sleep(nanoseconds: UInt64(delayInNanoseconds))
        
        DispatchQueue.main.async { [weak graph, weak pressNode] in
            guard let graph = graph,
                  let pressNode = pressNode else {
                      return
                  }
            
            
            graph.updateOutputs(at: loopIndex,
                                node: pressNode,
                                portValues: createNewValues(graph.graphStepState.graphTime),
                                media: nil)
        }
    }
}

// Need to update to be more like scroll animation eval
@MainActor
func pressInteractionEval(node: NodeViewModel,
                          graph: GraphState) -> ImpureEvalResult {
    node.loopedEval(PressInteractionNodeObserver.self,
                    graphState: graph) { values, evalObserver, interactiveLayer, loopIndex in
        pressInteractionOp(
            pressNode: node,
            values: values,
            evalObserver: evalObserver,
            loopIndex: loopIndex,
            interactiveLayer: interactiveLayer,
            graph: graph)
    }
    .toImpureEvalResult()
}

@MainActor
func pressInteractionOp(pressNode: NodeViewModel,
                        values: PortValues, // inputs' slice for this index
                        evalObserver: PressInteractionNodeObserver,
                        loopIndex: Int,
                        interactiveLayer: InteractiveLayer,
                        graph: GraphState) -> ImpureEvalOpResult {
        
    let isEnabled = values[safe: 1]?.getBool ?? false
    
    guard isEnabled else {
        return .init(outputs: pressNode.defaultOutputs)
    }
    
    let tapPosition = interactiveLayer.lastTappedLocation ?? .zero
    let dragVelocity = interactiveLayer.dragVelocity.toLayerSize
    let dragTranslation = interactiveLayer.dragTranslation.toLayerSize
    
    let wasSingleTapped = interactiveLayer.singleTapped
    let wasDoubleTapped = interactiveLayer.doubleTapped
    
    let currentGraphTime = graph.graphStepState.graphTime
    
    // Set true anytime we've received a LayerDragged event,
    // Set false anytime we receive a LayerDragEnded event
    let isDown = interactiveLayer.isDown
  
    let newValues: PortValues = [
        .bool(isDown), // Down
        // TODO: use previous single/double-tap time, instead of .zero, if there was no pulse?
        .pulse(wasSingleTapped ? currentGraphTime : .zero), // Tapped
        .pulse(wasDoubleTapped ? currentGraphTime : .zero), // Doubled Tapped
        .position(tapPosition), // Position
        .size(dragVelocity), // Velocity
        .size(dragTranslation) // Translation
    ]
    
    // Can we change the values on the interactive layer from inside this eval? or do we need to return an updated ephemeral state ?
    // TODO: are we guaranteed to run this press node's eval immediately after updating its singleTapped/doubleTapped value is updated? e.g. can we encounter a scenario where this press node's eval runs for a single-tap, but we've also scheduled an eval after a double-tap, and the single-tap eval run sets the double-tap false?
    if wasSingleTapped {
        interactiveLayer.singleTapped = false
    }
    
    if wasDoubleTapped {
        interactiveLayer.doubleTapped = false
    }
    
    return ImpureEvalOpResult(outputs: newValues)
}
