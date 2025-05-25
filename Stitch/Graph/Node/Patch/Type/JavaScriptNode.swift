//
//  JavaScriptNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/24/25.
//

import SwiftUI
import StitchSchemaKit
import JavaScriptCore

struct JavaScriptNode: PatchNodeDefinition {
    static let patch = Patch.javascript

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            // must contain one row to support add rows
            inputs: [.init(defaultType: .string, canDirectlyCopyUpstreamValues: true)],
            outputs: []
        )
    }
    
    @MainActor
    static func evaluate(node: NodeViewModel) -> EvalResult? {
        // 1. Create a context
        guard let jsContext = JSContext(),
              let patchNode = node.patchNodeViewModel else {
            fatalErrorIfDebug()
            return .init(outputsValues: [[.number(.zero)]])
        }

        // Construct inputs into JSON
        let inputValuesList = node.inputsValuesList
        let aiDataFromInputs = inputValuesList.map { inputValues in
            inputValues
                .map {
                    let aiData = Step(value: $0, valueType: $0.toNodeType)
                    let encodingString = try! aiData.encodeToPrintableString()
                    return encodingString
                }
        }

        // 3. Evaluate a script
        let script = patchNode.javascriptString
        let result = jsContext.evaluateScript("""
function evaluate(inputs) {
  return inputs
}

console.log("YOYOYO")
evaluate(\(aiDataFromInputs))
"""
        )
        
        guard let stringResult = result?.toString() else {
            return .init(outputsValues: [[.number(.zero)]])
        }
        
        log("javascript result: \(stringResult)")
        
//        let steps = try data.getOpenAISteps()
        
        return .init(outputsValues: [[.number(.zero)]])
    }
}
