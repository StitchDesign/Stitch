//
//  LoopRemoveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopRemoveNode: PatchNodeDefinition {
    static let patch: Patch = .loopRemove
    
    static let _defaultUserVisibleType: UserVisibleType = .string
    
    // overrides protocol
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "Loop",
                  defaultType: Self._defaultUserVisibleType),
            .init(label: "Index",
                  staticType: .number),
            .init(label: "Remove",
                  staticType: .pulse)
        ],
              outputs: [
                .init(label: "Loop", type: Self._defaultUserVisibleType),
                .init(label: "Index", type: .number)
              ])
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaReferenceObserver()
    }
    
}

@MainActor
func loopRemoveEval(node: PatchNode,
                    graphStep: GraphStepState) -> EvalResult {

    let inputsValues = node.inputs
    let graphTime = graphStep.graphTime
    
    // log("loopRemoveEval: inputsValues: \(inputsValues)")
    // log("loopRemoveEval: graphTime: \(graphTime)")
    
    // We must have values in the first two inputs
    guard let loopInput = inputsValues[safe: 0],
          loopInput.count > 0,
          let indexToRemove = inputsValues[safe: 1]?.first?.getNumber else {
        
        fatalErrorIfDebug()
        
        let valueOutputLoop = [(node.userVisibleType ?? LoopRemoveNode._defaultUserVisibleType).defaultPortValue]
        
        return .init(outputsValues: [
            valueOutputLoop,
            valueOutputLoop.asLoopIndices
        ])
    }
    
    // If we don't yet have outputs (e.g. graph open or reset), just use the first input.
    let currentOutput = (node.outputs.first?.isEmpty ?? true) ? loopInput : node.outputs.first!
    // log("loopRemoveEval: node.outputs: \(node.outputs)")
    // log("loopRemoveEval: currentOutput: \(currentOutput)")
    
    // Apparently: If ANY indices pulsed, then we insert.
    let pulsed: Bool = inputsValues[2].contains { (value: PortValue) -> Bool in
        if let pulseAt = value.getPulse {
            return pulseAt.shouldPulse(graphTime)
        }
        return false
    }

    let noChange = [
        currentOutput,
        currentOutput.asLoopIndices
    ]
    
    // NOTE: We are actually modifying the current output loop, NOT the input loop per se
    if pulsed {
        // log("loopRemoveEval: had pulse")
        
        let loopCount = currentOutput.count
        
        // TODO: logic here might be `mod`, actually?
        // Note: Suppose a loop input like [a, b, c, d], so count = 4,
        // then -1 index is same as (count + index) = 3
        let removalIndex: Int = Int((indexToRemove < 0) ? (Double(loopCount) + indexToRemove) : indexToRemove)
        
        // We always use a positive index to remove.
        if removalIndex < 0 {
            // log("loopRemoveEval: removalIndex \(removalIndex) should have been positive")
            return .init(outputsValues: noChange)
        }
        
        var newOutputLoop = currentOutput
        newOutputLoop.remove(at: removalIndex)
        // log("loopRemoveEval: newOutputLoop: \(newOutputLoop)")
        
        // Never return an empty output
        if newOutputLoop.isEmpty {
            // log("loopRemoveEval: newOutputLoop would be empty")
            newOutputLoop = [node.userVisibleType?.defaultPortValue ?? LoopRemoveNode._defaultUserVisibleType.defaultPortValue]
        }
        
        return .init(outputsValues: [
            newOutputLoop,
            newOutputLoop.asLoopIndices
        ])
    } else {
        // log("loopRemoveEval: no pulse")
        return .init(outputsValues: noChange)
    }
}
