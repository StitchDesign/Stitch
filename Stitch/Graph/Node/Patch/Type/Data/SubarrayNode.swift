//
//  SubarrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct SubarrayPatchNode: PatchNodeDefinition {
    static let patch = Patch.subarray
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONArray)],
                    label: "Array"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Location"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Length"
                )
            ],
            outputs: [
                .init(
                    label: "Subarray",
                    type: .json
                )
            ]
        )
    }
}


// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami
@MainActor
func subarrayEval(node: PatchNode) -> EvalResult {
    let opWithIndex: OpWithIndex<PortValue> = { (values: PortValues, index: Int) -> PortValue in
        let json1 = values.first?.getJSON ?? .emptyJSONArray
        let location = Int(values[safe: 1]?.getNumber ?? .zero)
        let length = Int(values[safe: 2]?.getNumber ?? .zero)
        let result = jsonSubarray(json1,
                                  location: location,
                                  length: length)
        return .init(result)
    }
    
    return .init(outputsValues: [loopedEval(inputsValues: node.inputs,
                                            evalOp: opWithIndex)])
}
