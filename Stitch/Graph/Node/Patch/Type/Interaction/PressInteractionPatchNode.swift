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
    var prevTapTime: TimeInterval?
    let actor: PressInteractionActor = .init()
}

actor PressInteractionActor {
    func delayTap(delayValue: Double,
                  newTapTime: Double,
                  pressNode: NodeViewModel,
                  evalObserver: PressInteractionNodeObserver,
                  graph: GraphDelegate,
                  loopIndex: Int,
                  createNewValues: @escaping (TimeInterval) -> PortValues) async throws {
        let delayInNanoseconds = delayValue * Double(nanoSecondsInSecond)
        try await Task.sleep(nanoseconds: UInt64(delayInNanoseconds))
        DispatchQueue.main.async { [weak graph, weak pressNode] in
            guard let graph = graph,
                  let pressNode = pressNode else {
                      return
                  }
            
            
            graph.updateOutputs(at: loopIndex,
                                node: pressNode,
                                portValues: createNewValues(graph.graphStepState.graphTime))
        }
    }
}

// Need to update to be more like scroll animation eval
@MainActor
func pressInteractionEval(node: NodeViewModel,
                          graph: GraphDelegate,
                          graphStep: GraphStepState) -> ImpureEvalResult {
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
                        graph: GraphDelegate) -> ImpureEvalOpResult {
    let isEnabled = values[safe: 1]?.getBool ?? false
    let delayValue = values[safe: 2]?.getNumber ?? .zero
    let prevTapTime = evalObserver.prevTapTime ?? .zero
    let prevValueTapTime = values[safe: 4]?.getPulse ?? .zero
    
    let newTapTime: TimeInterval = interactiveLayer.firstPressEnded ?? .zero
    let newDoubleTapTime: TimeInterval = interactiveLayer.secondPressEnded ?? .zero
    
    let registeredNewTap = prevTapTime != newTapTime
    let hasDelay = delayValue != .zero
    // Create delay task if nonzero delay, not loading already, and new tap
    let willDelayTap = hasDelay && registeredNewTap // && !evalObserver.isLoading
    let tapPosition = interactiveLayer.lastTappedLocation ?? .zero
    let dragVelocity = interactiveLayer.dragVelocity.toLayerSize
    let dragTranslation = interactiveLayer.dragTranslation.toLayerSize
    
    guard isEnabled else {
        return .init(outputs: pressNode.defaultOutputs)
    }
    
    // state.isDown:
    // set true anytime we've received a LayerDragged event,
    // set false anytime we receive a LayerDragEnded event
    let isDown = interactiveLayer.isDown
    
    let createNewValues = { @Sendable (_tapTimeToDisplay: TimeInterval) -> PortValues in
        [
            .bool(isDown), // Down
            .pulse(_tapTimeToDisplay), // Tapped
            .pulse(newDoubleTapTime), // Doubled Tapped
            .position(tapPosition), // Position
            .size(dragVelocity), // Velocity
            .size(dragTranslation) // Translation
        ]
    }
    
    if willDelayTap {
        evalObserver.prevTapTime = newTapTime
        
        Task(priority: .high) { [weak evalObserver, weak graph] in
            guard let evalObserver = evalObserver,
                  let graph = graph else {
                return
            }
            
            try? await evalObserver.actor.delayTap(delayValue: delayValue,
                                                   newTapTime: newTapTime,
                                                   pressNode: pressNode,
                                                   evalObserver: evalObserver,
                                                   graph: graph,
                                                   loopIndex: loopIndex,
                                                   createNewValues: createNewValues)
        }
    }
    
    // Use last known press immediately if no delay, else use previous output value
    // letting the timer set the output
    let tapTimeToDisplay = hasDelay ? prevValueTapTime : newTapTime
    return ImpureEvalOpResult(outputs: createNewValues(tapTimeToDisplay))
}
