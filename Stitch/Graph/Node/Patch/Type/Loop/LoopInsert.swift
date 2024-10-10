//
//  LoopFilter.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let fakeIndex = -1.0

struct LoopInsertNode: PatchNodeDefinition {
    static let patch = Patch.loopInsert

    static let defaultUserVisibleType: UserVisibleType? = .color

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.color(.red), .color(.yellow), .color(.blue), .color(.green)],
                    label: "Loop"
                ),
                .init(
                    defaultValues: [.color(.purple)],
                    label: "Value"
                ),
                .init(
                    label: "Index",
                    staticType: .number
                ),
                .init(
                    label: "Insert",
                    staticType: .pulse
                )
            ],
            outputs: [
                .init(
                    label: "Loop",
                    type: type ?? .color
                ),
                .init(
                    label: "Index",
                    type: .number
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        // If we have existing inputs, then we're deserializing,
        // and should base internal state and starting outputs on those inputs.
        LoopingEphemeralObserver()
    }
}

final class LoopingEphemeralObserver: NodeEphemeralObservable {
    var previousValues: PortValues = []
}

extension PortValues {
    var unwrapAsPulses: [TimeInterval] {
        let asPulses = self.compactMap(\.getPulse)
        if asPulses.count != self.count {
            log("PortValues extension: unwrapAsPulses: could not unwrap", .logToServer)
            return self.map { $0.getPulse ?? .zero }
        }
        return asPulses
    }

    // Did at least one index in this loop pulse?
    func someIndexPulsed(_ graphTime: TimeInterval) -> Bool {
        self.unwrapAsPulses.contains { $0.shouldPulse(graphTime) }
    }
}

// TODO: revisit how this works with indices
@MainActor
func loopInsertEval(node: PatchNode,
                    graphStep: GraphStepState) -> ImpureEvalResult {
    
    guard let computedState = node.ephemeralObservers?.first as? LoopingEphemeralObserver else {
        fatalErrorIfDebug()
        return .init(outputsValues: node.defaultOutputsList)
    }

    let defaultFirstInputs: PortValues = [.color(.red), .color(.yellow), .color(.blue), .color(.green)]

    let inputsValues = node.inputs
    let outputsValues = node.outputs
    let graphTime = graphStep.graphTime

    // Apparently: If ANY indices pulsed, then we insert.
    let shouldPulse: Bool = (inputsValues[safe: 3] ?? []).contains { (value: PortValue) -> Bool in
        if let pulseAt = value.getPulse {
            return pulseAt.shouldPulse(graphTime)
        }
        return false
    }

    let currentInput = inputsValues.first ?? defaultFirstInputs
    let currentInputLoop: PortValues = currentInput
    let previousInputLoop: PortValues = computedState.previousValues
    let inputLoopChanged = currentInputLoop != previousInputLoop

    // Update previous inputs
    computedState.previousValues = currentInput

    //    log("loopInsertEval: currentInputLoop: \(currentInputLoop)")
    //    log("loopInsertEval: nodeComputedState.previousValues: \(nodeComputedState.previousValues)")
    //    log("loopInsertEval: previousInputLoop: \(previousInputLoop)")


    let shouldEval = shouldPulse || inputLoopChanged


    if inputLoopChanged {
        //        log("loopInsertEval: will set input loop directly in output")
        let newOutputsValues: PortValuesList = [
            currentInput,
            buildIndicesLoop(loop: currentInput)
        ]
        return .init(outputsValues: newOutputsValues)
    } else if shouldEval {
        //        log("loopInsertEval: will insert")

        // If we have a new loop input, then we use that;
        // else we use current output
        var loop: PortValues = inputLoopChanged
            ? (inputsValues.first ?? defaultFirstInputs)
            : outputsValues.first ?? [.number(.zero)]

        // Loops can be inserted into `loop`, but flat.
        let valueToInsert: PortValues = inputsValues[safe: 1] ?? [.color(.purple)]

        /*
         Notes:
         1. negative indices must be turned to loop-insert-friendly ones
         2. apparently, if index input is loop, we default to index 0
         */
        let indexToInsertAt: Int = [inputsValues[safe: 2]?.first?.getNumber?
                                        .toInt ?? .zero]
            .asLoopInsertFriendlyIndices(loop.count).first ?? .zero

        // TODO: mod the index-to-insert-at by; but an index > loop
        valueToInsert.forEach { (value: PortValue) in
            if (indexToInsertAt < 0) || (indexToInsertAt > (loop.count - 1)) {
                // .insert doesn't support negative numbers
                //                log("loopInsertEval: will add value to back: \(value)")
                loop.append(value)
            } else {
                // replaces the value?
                //                log("loopInsertEval: will add value: \(value) at \(indexToInsertAt)")
                loop.insert(value, at: indexToInsertAt)
            }
        }
        let newOutputsValues: PortValuesList = [loop, buildIndicesLoop(loop: loop)]

        return .init(outputsValues: newOutputsValues)
    } else {
        //        log("loopInsertEval: will not insert")
        let _values = outputsValues.first ?? [.number(.zero)]
        let newOutputsValues: PortValuesList = [
            _values,
            buildIndicesLoop(loop: _values)
        ]
        return .init(outputsValues: newOutputsValues)
    }
}
