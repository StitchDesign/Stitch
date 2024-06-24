//
//  ValueForKeyNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON


struct ValueForKeyNode: PatchNodeDefinition {
    static let patch = Patch.valueForKey
    
    static var defaultUserVisibleType: UserVisibleType? { .json }
    
    static func rowDefinitions(for type: NodeType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(label: "Object", staticType: .json),
                .init(label: "Key", staticType: .string)
            ],
            outputs: [
                .init(label: "Value",
                      type: .json)
            ]
        )
    }
}

@MainActor
func valueForKeyEval(node: PatchNode,
                      graphStepState: GraphStepState) -> EvalResult {

    let op: Operation = { (values: PortValues) -> PortValue in
        let jsonObject = values.first?.getJSON ?? .emptyJSONObject
        let key = values[safe: 1]?.getString?.string ?? .empty
        return coerceJSONToNodeType(
            json: getValueAtKeyPath(jsonObject, key),
            nodeType: node.userVisibleType ?? ValueAtPathNode.defaultUserVisibleType ?? .json,
            graphTime: graphStepState.graphTime)
    }

    return .init(outputsValues: singeOutputEvalResult(op, node.inputs))
}
