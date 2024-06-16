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

@MainActor
func indexOfNode(id: NodeId,
                 startingJson: StitchJSON = emptyStitchJSONObject,
                 position: CGSize = .zero,
                 zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Array", [.json(startingJson)]),
        ("Item", [.string(.init(.empty))])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            ("Index", [.number(-1)]),
        ("Contains", [.bool(false)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .indexOf,
        inputs: inputs,
        outputs: outputs)
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami

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
