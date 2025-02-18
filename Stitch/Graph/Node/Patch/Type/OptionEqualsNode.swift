//
//  OptionEqualsNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/23/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func optionEqualsNode(id: NodeId,
                      position: CGSize = .zero,
                      zIndex: Double = 0) -> PatchNode {

    // default
    //    var opt1: PortValue = colorDefaultFalse
    //    var opt2: PortValue = colorDefaultTrue
    let opt1: PortValue = .string(.init("a"))
    let opt2: PortValue = .string(.init("b"))

    let inputs = toInputs(
        id: id,
        values:
            //            ("Option", [numberDefaultFalse]),
            ("Option", [.string(.init("a"))]),
        (nil, [opt1]),
        (nil, [opt2]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [opt1]),
        ("Equals", [.bool(true)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .optionEquals,
        //        userVisibleType: .color,
        userVisibleType: .string,
        inputs: inputs,
        outputs: outputs)
}

// returns `(.number(index), .bool(equals))` outputs regardless of node-type
@MainActor
func optionEqualsEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in

        // port-value type agnostic
        let selection: PortValue = values.first!

        log("optionEqualsEval: selection: \(selection)")
        log("optionEqualsEval: values: \(values)")

        let options: PortValues = Array(values.dropFirst())

        if let selectedValueIndex = options.firstIndex(where: { $0 == selection }) {
            log("optionEqualsEval: selectedValueIndex: \(selectedValueIndex)")
            return (
                .number(Double(selectedValueIndex)),
                .bool(true)
            )
        }

        log("optionEqualsEval: could not find selection")
        return (
            // -1 to `index`, since we ignore the first input for index-counting
            .number(Double(inputs.count - 1)),
            .bool(false)
        )
    }

    return resultsMaker2(inputs)(op)
}
