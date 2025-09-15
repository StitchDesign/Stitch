//
//  ArrayJoinNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct ArrayJoinPatchNode: PatchNodeDefinition {
    static let patch = Patch.arrayJoin
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: ""
                ),
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .json
                )
            ]
        )
    }
}

@MainActor
func arrayJoinNode(id: NodeId,
                   startingJson: StitchJSON = emptyStitchJSONObject,
                   position: CGPoint = .zero,
                   zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.json(startingJson)]),
        (nil, [.json(startingJson)])
    )

    let outputJson: StitchJSON = startingJson

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            (nil, [.json(outputJson)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .arrayJoin,
        inputs: inputs,
        outputs: outputs)
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami
@MainActor
func arrayJoinEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        var result = emptyJSONArray
        for json in values.compactMap(\.getJSON) {
            result = arrayJoin(result, json)
        }
        return .init(result)
    }

    return singeOutputEvalResult(op, inputs)
}
