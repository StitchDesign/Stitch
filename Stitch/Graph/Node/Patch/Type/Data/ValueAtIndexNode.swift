//
//  ValueAtIndexNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct ValueAtIndexNode: PatchNodeDefinition {
    static let patch = Patch.valueAtIndex
    
    static var defaultUserVisibleType: UserVisibleType? { .json }
    
    static func rowDefinitions(for type: NodeType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(label: "Array", staticType: .json),
                .init(label: "Index", staticType: .number)
            ],
            outputs: [
                .init(label: "Value",
                      type: .json)
            ]
        )
    }
}

@MainActor
func valueAtIndexEval(node: PatchNode,
                      graphStepState: GraphStepState) -> EvalResult {
    
    let graphTime = graphStepState.graphTime
    let nodeType = node.userVisibleType ?? ValueAtIndexNode.defaultUserVisibleType ?? .json
    
    let op: Operation = { (values: PortValues) -> PortValue in
        let jsonObject = values.first?.getJSON ?? emptyJSONObject
        let index = Int(values[safe: 1]?.getNumber ?? .zero)

        //        log("valueAtIndexEval: index: \(index)")
        //        log("valueAtIndexEval: jsonObject: \(jsonObject)")
        //        log("valueAtIndexEval: getValueAtIndex(jsonObject, index): \(getValueAtIndex(jsonObject, index))")

        if let j = getValueAtIndex(jsonObject, index) {
            // Need to coerce to specific nodeType
            return coerceJSONToNodeType(json: j,
                                 nodeType:  nodeType,
                                 graphTime: graphTime)
        } else {
            //            log("Nothing found at index: \(index)")
            return defaultFalseJSON
        }
    }

    let newOutputs = singeOutputEvalResult(op, node.inputs)
    return .init(outputsValues: newOutputs)
}

// Given a json (with a single array-item or single value),
// return a PortValue

// TODO: add more types here that we can pull from the json?
// TODO: move the "json + some node type -> PortValue" coercion logic to more PortValue coercers
@MainActor
func coerceJSONToNodeType(json: JSON,
                          nodeType: NodeType,
                          graphTime: TimeInterval) -> PortValue {
    
    // Most json -> some NodeType/PortValue.type coercions are not defined; so we do them here via switch;
    // but if we can't
    let defaultValue = [PortValue.json(.init(json))]
        .coerce(to: nodeType.toPortValue,
                currentGraphTime: graphTime)
        .first ?? defaultFalseJSON
    
    switch nodeType {
    case .number:
        if let x = json.first?.1.number {
            return .number(Double(truncating: x))
        }
        return defaultValue
        
    case .string:
        if let x = json.first?.1.string {
            return .string(.init(x))
        }
        return defaultValue
        
    case .bool:
        if let x = json.first?.1.bool {
            return .bool(x)
        }
        return defaultValue
        
    case .json:
        return .json(.init(json))
        
    default:
        return .json(.init(json))
    }
}
