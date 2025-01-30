//
//  JSONArrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct JSONArrayNode: PatchNodeDefinition {
    static let patch: Patch = .jsonArray
    
    static let defaultUserVisibleType: UserVisibleType? = .number
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "", defaultType: .number),
            .init(label: "", defaultType: .number)
        ],
              outputs: [
                .init(label: "Array",
                      type: .json)
              ]
        )
    }
}

@MainActor
func jsonArrayEval(node: NodeViewModel) -> EvalResult {
    node.loopedEval(shouldAddOutputs: false) { values, index in
        let j = JSON.jsonArrayFromValues(values)
        // log("jsonArrayEval: j: \(j)")
        return [.json(.init(j))]
    }
    .createPureEvalResult()
}
