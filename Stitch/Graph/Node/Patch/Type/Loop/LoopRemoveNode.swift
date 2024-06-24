//
//  LoopRemoveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func loopRemoveNode(id: NodeId,
                    position: CGSize = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let valuesLoop: PortValues = [.number(.zero)]
    let indicesLoop = buildIndicesLoop(loop: valuesLoop)

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", valuesLoop), // 0
        // -1 = remove from end
        ("Index", [.number(.zero)]), // 1
        // Insertion only happens when
        ("Remove", [pulseDefaultFalse])) // 2

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            ("Loop", valuesLoop),
        ("Index", indicesLoop))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopRemove,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func loopRemoveEval(node: PatchNode,
                    graphStep: GraphStepState) -> EvalResult {

    let inputsValues = node.inputs
    let graphTime = graphStep.graphTime

    // Apparently: If ANY indices pulsed, then we insert.
    let pulsed: Bool = inputsValues[2].contains { (value: PortValue) -> Bool in
        if let pulseAt = value.getPulse {
            return pulseAt.shouldPulse(graphTime)
        }
        return false
    }

    let shouldPulse = pulsed

    if shouldPulse {
        log("loopRemoveEval: had pulse")
        var loop: PortValues = inputsValues.first!

        // Loops can be inserted into `loop`, but flat.
        let valueToInsert: PortValues = inputsValues[1]

        // Apparently: if index port receives a loop, we default to index = 0.
        let indexToRemoveAt: Int = Int(
            inputsValues[1].count > 1
                ? inputsValues[1].first!.defaultFalseValue.getNumber ?? 0.0
                : inputsValues[1].first!.getNumber ?? 0.0)

        valueToInsert.forEach { (value: PortValue) in
            if (indexToRemoveAt < 0) || (indexToRemoveAt > (loop.count - 1)) {
                log("loopRemoveEval: will remove value from back: \(value)")
                loop = loop.dropLast(1)
            } else {
                log("loopRemoveEval: will remove value: \(value) at \(indexToRemoveAt)")
                loop.remove(at: indexToRemoveAt)
            }
        }

        let newOutputsValues: PortValuesList = [loop,
                                                loop.asLoopIndices]
        return .init(outputsValues: newOutputsValues)
    } else {
        log("loopRemoveEval: no pulse")
        // if we didn't pulse, just pass on the input loop

        // TODO: no, this seems wrong; we end up losing the past progress of the pulse that removed something; revisit
        let inputLoop = inputsValues.first!
        let newOutputsValues: PortValuesList = [inputLoop,
                                                inputLoop.asLoopIndices]
        return .init(outputsValues: newOutputsValues)
    }
}
