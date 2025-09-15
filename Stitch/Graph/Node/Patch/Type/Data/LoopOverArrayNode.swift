//
//  LoopOverArrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct LoopOverArrayPatchNode: PatchNodeDefinition {
    static let patch = Patch.loopOverArray
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: "Array"
                )
            ],
            outputs: [
                .init(
                    label: "Index",
                    type: .number
                ),
                .init(
                    label: "Items",
                    type: .json
                )
            ]
        )
    }
}

func loopOverArrayEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {

    // loopOverArray expects its input to contain a SINGLE JSON value (a json array);
    // if we provide eg a loop of JSONS to its input, only the first JSON will be used.
    let jsonArray = inputs.first?.first?.getJSON ?? .emptyArray
    let (indicesLoop, valuesLoop) = JSONArrayToLoops(jsonArray)

    return [indicesLoop, valuesLoop]
}
