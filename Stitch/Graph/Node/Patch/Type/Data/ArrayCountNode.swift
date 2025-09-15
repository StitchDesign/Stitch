//
//  ArrayCountNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct ArrayCountPatchNode: PatchNodeDefinition {
    static let patch = Patch.arrayCount
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
                    type: .number
                )
            ]
        )
    }
}


// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami
@MainActor
func arrayCountEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let jsonArray = values.first?.getJSON ?? .emptyArray
        //        log("arrayCountEval: jsonArray: \(jsonArray)")
        //        log("arrayCountEval: jsonArray.count: \(jsonArray.count)")
        return .number(Double(jsonArray.count))
    }

    return singeOutputEvalResult(op, inputs)
}
