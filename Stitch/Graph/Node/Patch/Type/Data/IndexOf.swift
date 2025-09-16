//
//  IndexOf.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct IndexOfPatchNode: PatchNodeDefinition {
    static let patch = Patch.indexOf
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: "Array",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Item"
                )
            ],
            outputs: [
                .init(
                    label: "Index",
                    type: .number
                ),
                .init(
                    label: "Contains",
                    type: .bool
                )
            ]
        )
    }
}


// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami

@MainActor
func indexOfEval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in
        let json1 = values.first?.getJSON ?? emptyJSONArray
        let item = values[safe: 1]?.getString?.string ?? .empty
        let result = indexOf(json1, item: item)
        return (
            .number(Double(result.0)),
            .bool(result.1)
        )
    }

    return resultsMaker2(inputs)(op)
}
