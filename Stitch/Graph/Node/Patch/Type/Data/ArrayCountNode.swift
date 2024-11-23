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

@MainActor
func arrayCountNode(id: NodeId,
                    startingJson: StitchJSON = emptyStitchJSONObject,
                    position: CGSize = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Array", [.json(startingJson)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            (nil, [.number(Double(startingJson.value.count))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .arrayCount,
        inputs: inputs,
        outputs: outputs)
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami
@MainActor
func arrayCountEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let jsonArray = values.first!.getJSON!
        //        log("arrayCountEval: jsonArray: \(jsonArray)")
        //        log("arrayCountEval: jsonArray.count: \(jsonArray.count)")
        return .number(Double(jsonArray.count))
    }

    return singeOutputEvalResult(op, inputs)
}
