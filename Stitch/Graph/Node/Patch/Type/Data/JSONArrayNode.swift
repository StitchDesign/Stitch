//
//  JSONArrayNode.swift
//  prototype
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
    
    static func rowDefinitions(for type: StitchSchemaKit.UserVisibleType?) -> NodeRowDefinitions {
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
    node.loopedEval { values, index in
        let j = JSON.jsonArrayFromValues(values)
        //        #if DEV_DEBUG
        //        log("jsonArrayEval: j: \(j)")
        //        #endif
        return [.json(.init(j))]
    }
    .createPureEvalResult()
}
