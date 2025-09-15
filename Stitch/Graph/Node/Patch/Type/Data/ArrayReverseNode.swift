//
//  ArrayReverseNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct ArrayReversePatchNode: PatchNodeDefinition {
    static let patch = Patch.arrayReverse
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: "Array"
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
func arrayReverseEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let json1 = values.first?.getJSON ?? .emptyJSONArray
        let result = arrayReverse(json1)
        return .init(result)
    }

    return singeOutputEvalResult(op, inputs)
}
