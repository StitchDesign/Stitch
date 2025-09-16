//
//  OptionEqualsNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/23/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct OptionEqualsPatchNode: PatchNodeDefinition {
    static let patch = Patch.optionEquals
    static let defaultUserVisibleType: UserVisibleType? = .string

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init("a"))],
                    label: "Option",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.string(.init("a"))],
                    label: ""
                ),
                .init(
                    defaultValues: [.string(.init("b"))],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .string
                ),
                .init(
                    label: "Equals",
                    type: .bool
                )
            ]
        )
    }
}

// returns `(.number(index), .bool(equals))` outputs regardless of node-type
@MainActor
func optionEqualsEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in

        // port-value type agnostic
        let selection: PortValue = values.first!

        // log("optionEqualsEval: selection: \(selection)")
        // log("optionEqualsEval: values: \(values)")

        let options: PortValues = Array(values.dropFirst())

        if let selectedValueIndex = options.firstIndex(where: { $0 == selection }) {
            // log("optionEqualsEval: selectedValueIndex: \(selectedValueIndex)")
            return (
                .number(Double(selectedValueIndex)),
                .bool(true)
            )
        }

        // log("optionEqualsEval: could not find selection")
        return (
            // -1 to `index`, since we ignore the first input for index-counting
            .number(Double(inputs.count - 1)),
            .bool(false)
        )
    }

    return resultsMaker2(inputs)(op)
}

