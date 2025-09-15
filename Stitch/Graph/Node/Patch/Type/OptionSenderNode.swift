//
//  OptionSenderNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/29/22.
//

import Foundation
import StitchSchemaKit

struct OptionSenderPatchNode: PatchNodeDefinition {
    static let patch = Patch.optionSender
    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [numberDefaultFalse],
                    label: "Option"
                ),
                .init(
                    defaultValues: [numberDefaultFalse],
                    label: "Value"
                ),
                .init(
                    defaultValues: [numberDefaultFalse],
                    label: "Default"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                ),
                .init(
                    label: "",
                    type: .number
                ),
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }
}

// TODO: OptionSender can have an arbitrary number of outputs
// We currently don't have any logic in the app for adding outputs (only inputs)
let OPTION_SENDER_PATCH_NODE_OUTPUT_COUNT: Int = 3


@MainActor
func optionSenderEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation3 = { (values: PortValues) -> (PortValue, PortValue, PortValue) in

        // which output we should sent `value` to;
        // ie selection > output.count, then `value` gets sent nowhere
        let selection: Int = Int(values.first?.getNumber ?? .zero)
        let value: PortValue = values[1]

        // what every other output gets:
        let defaultValue: PortValue = values[2]

        // log("optionSenderEval: selection: \(selection)")
        // log("optionSenderEval: value: \(value)")
        // log("optionSenderEval: defaultValue: \(defaultValue)")

        if selection == 0 {
            return (value, defaultValue, defaultValue)
        }
        if selection == 1 {
            return (defaultValue, value, defaultValue)
        }
        if selection == 2 {
            return (defaultValue, defaultValue, value)
        } else {
            return (defaultValue, defaultValue, defaultValue)
        }
    }

    // optionSender can take nearly every type,
    // but operation doesn't change by type
    return resultsMaker3(inputs)(op)
}
