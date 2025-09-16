//
//  LoopSumNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopSumPatchNode: PatchNodeDefinition {
    static let patch = Patch.loopSum
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let effectiveType = type ?? .number
        let defaultValue = effectiveType.defaultPortValue

        return .init(
            inputs: [
                .init(
                    defaultValues: [defaultValue],
                    label: "Loop"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }
}

// TODO: Origami docs indicate that this node can be number, index or bool type, but Origami in practice only has a single node type;
// ... and adding together a list of five bools is somehow "15", or some previously saved/used value?
func loopSumEval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {
    guard let input = inputs.first else {
        fatalErrorIfDebug()
        return inputs
    }
    
    let ns: [Double] = input.map { $0.getNumber ?? .zero }
    return [
        [.number(ns.reduce(0.0, +))]
    ]
}
