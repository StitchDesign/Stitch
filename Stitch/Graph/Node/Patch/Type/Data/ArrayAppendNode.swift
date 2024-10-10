//
//  ArrayAppendNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct ArrayAppendNode: PatchNodeDefinition {
    static let patch: Patch = .arrayAppend
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "Array", defaultType: .json),
            .init(label: "Item", defaultType: .json),
            .init(label: "Append", staticType: .bool)
        ], outputs: [
            .init(label: "Array",
                  type: .json)
        ])
    }
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami
@MainActor
func arrayAppendEval(node: NodeViewModel) -> EvalResult {
    node.loopedEval { values, loopIndex in
        let jsonArray = values.first?.getJSON ?? emptyJSONObject
        let item = values[safe: 1]?.getStitchJSON ?? emptyStitchJSONObject
        // DO NOT NEED a check like 'Have we already added this item?',
        // because operation is idempotent
        let shouldAppend = values[safe: 2]?.getBool ?? false
        
        let previousValue = values.last ?? defaultFalseJSON
        
        log("arrayAppendEval: shouldAppend: \(shouldAppend)")
        
        if shouldAppend,
           let j = jsonArray.appendToJSONArray(.json(item)) {
            log("arrayAppendEval: arrayAppendEval: j: \(j)")
            return [.json(j.toStitchJSON)]
        } else {
            return [previousValue]
        }
    }
    .createPureEvalResult()
}
