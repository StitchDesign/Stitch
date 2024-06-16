//
//  JSONObjectNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct JSONObjectNode: PatchNodeDefinition {
    static let patch: Patch = .jsonObject
    
    static let defaultUserVisibleType: UserVisibleType? = .number
    
    static func rowDefinitions(for type: StitchSchemaKit.UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "Key", staticType: .string),
            .init(label: "Value", defaultType: .number)
        ],
              outputs: [
                .init(label: "Object",
                      type: .json)
              ]
        )
    }
}

@MainActor
func jsonObjectEval(node: NodeViewModel) -> EvalResult {
    node.loopedEval { values, _ in
        let key = values.first?.getString?.string ?? ""
        
        guard let value = values[safe: 1] else {
            log("jsonObjectEval.op error: could not get value at first index.")
            return [defaultFalseJSON]
        }
        
        let j = JSON.jsonObjectFromKeyAndValue(key, value)
        //        log("jsonObjectEval: j: \(j)")
        return [.json(j.toStitchJSON)]
    }
    .createPureEvalResult()
}
