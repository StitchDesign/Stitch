//
//  OptionSenderNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/29/22.
//

import Foundation
import StitchSchemaKit

// TODO: OptionSender can have an arbitrary number of outputs
// We currently don't have any logic in the app for adding outputs (only inputs)
let OPTION_SENDER_PATCH_NODE_OUTPUT_COUNT: Int = 3

@MainActor
func optionSenderNode(id: NodeId,
                      n: Double? = nil,
                      n2: Double? = nil,
                      position: CGSize = .zero,
                      zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Option", [numberDefaultFalse]),
        ("Value", [numberDefaultFalse]),
        ("Default", [numberDefaultFalse]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [numberDefaultFalse]),
        (nil, [numberDefaultFalse]),
        (nil, [numberDefaultFalse])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .optionSender,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

func optionSenderEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation3 = { (values: PortValues) -> (PortValue, PortValue, PortValue) in

        // which output we should sent `value` to;
        // ie selection > output.count, then `value` gets sent nowhere
        let selection: Int = Int(values.first?.getNumber ?? .zero)
        let value: PortValue = values[1]

        // what every other output gets:
        let defaultValue: PortValue = values[2]

        log("selection: \(selection)")
        log("value: \(value)")
        log("defaultValue: \(defaultValue)")

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
