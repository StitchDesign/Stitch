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
