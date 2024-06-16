//
//  ValueAtPathNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct ValueAtPathNode: PatchNodeDefinition {
    static let patch = Patch.valueAtPath
    
    static var defaultUserVisibleType: UserVisibleType? { .json }
    
    static func rowDefinitions(for type: NodeType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(label: "Object", staticType: .json),
                .init(label: "Path", staticType: .string)
            ],
            outputs: [
                .init(label: "Value",
                      type: .json)
            ]
        )
    }
}

// if first input is a json object rather than an array,
// this append will fail / should fail, per Origami


@MainActor
func valueAtPathEval(node: PatchNode,
                     graphStepState: GraphStepState) -> EvalResult {
    
    let op: Operation = { (values: PortValues) -> PortValue in
        let json1 = values.first?.getJSON ?? emptyJSONObject
        let path = values[safe: 1]?.getString?.string ?? .empty
        
        return coerceJSONToNodeType(
            json: getValueAtKeyPath(json1, path),
            nodeType: node.userVisibleType ?? ValueAtPathNode.defaultUserVisibleType ?? .json,
            graphTime: graphStepState.graphTime)
    }

    return .init(outputsValues: resultsMaker(node.inputs)(op))
}
