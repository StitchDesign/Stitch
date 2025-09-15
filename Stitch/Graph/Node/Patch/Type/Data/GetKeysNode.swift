//
//  GetKeysNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct GetKeysPatchNode: PatchNodeDefinition {
    static let patch = Patch.getKeys
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: "Object"
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
func getKeysEval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let json1 = values.first?.getJSON ?? .emptyJSONArray
        let result = jsonKeys(json1)
        return .json(result.toStitchJSON)
    }

    return singeOutputEvalResult(op, inputs)
}
