//
//  LoopOverArrayNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

@MainActor
func loopOverArrayNode(id: NodeId,
                       key: String = "",
                       startingJson: StitchJSON = emptyStitchJSONObject,
                       position: CGSize = .zero,
                       zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Array", [.json(startingJson)]) // 0
    )

    let outputJson: StitchJSON = emptyStitchJSONObject

    // loop Builder has TWO outputs:
    // 1. indices: ALWAYS a loop of ints, where each int is just an index
    // 2. values: a loop of the user-chosen value-type (here: color)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            ("Index", [.number(0)]),

        // is always a loop of jsons
        ("Items", [.json(outputJson)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopOverArray,
        inputs: inputs,
        outputs: outputs)
}

func loopOverArrayEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {

    // loopOverArray expects its input to contain a SINGLE JSON value (a json array);
    // if we provide eg a loop of JSONS to its input, only the first JSON will be used.

    let jsonArray = inputs.first!.first!.getJSON!
    let (indicesLoop, valuesLoop) = JSONArrayToLoops(jsonArray)

    return [indicesLoop, valuesLoop]
}
