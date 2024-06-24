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

@MainActor
func getKeysNode(id: NodeId,
                 startingJson: StitchJSON = emptyStitchJSONObject,
                 position: CGSize = .zero,
                 zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Object", [.json(startingJson)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            (nil, [.json(emptyStitchJSONArray)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .getKeys,
        inputs: inputs,
        outputs: outputs)
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami

func getKeysEval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let json1 = values.first?.getJSON ?? .emptyJSONArray
        let result = jsonKeys(json1)
        return .json(result.toStitchJSON)
    }

    return singeOutputEvalResult(op, inputs)
}
