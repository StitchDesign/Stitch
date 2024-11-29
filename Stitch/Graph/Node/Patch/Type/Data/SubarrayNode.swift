//
//  SubarrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

@MainActor
func subarrayNode(id: NodeId,
                  startingJson: StitchJSON = emptyStitchJSONArray,
                  position: CGSize = .zero,
                  zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Array", [.json(startingJson)]),
        ("Location", [.number(0)]),
        ("Length", [.number(0)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            ("Subarray", [.json(emptyStitchJSONArray)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .subarray,
        inputs: inputs,
        outputs: outputs)
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami
@MainActor
func subarrayEval(inputs: PortValuesList,
                  outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        //        let json1 = values.first!.getJSON ?? emptyJSONArray
        let json1 = values.first?.getJSON ?? .emptyJSONArray
        let location = Int(values[safe: 1]?.getNumber ?? .zero)
        let length = Int(values[safe: 2]?.getNumber ?? .zero)
        let result = jsonSubarray(json1,
                                  location: location,
                                  length: length)
        return .init(result)
    }

    return resultsMaker(inputs)(op)
}
