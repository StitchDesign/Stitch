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
                    Step(value: $0, valueType: $0.toNodeType)
                }
        }
        
        // Encode ➜ JSON ➜ Foundation object ➜ JS
        guard let data = try? JSONEncoder().encode(aiDataFromInputs),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {   // [String: Any]
            fatalErrorIfDebug()
            return .init(outputsValues: [[.number(.zero)]])
        }
        
        jsContext.setObject(jsonObject, forKeyedSubscript: "node_inputs" as NSString)
        
        // 3. Evaluate a script
        let script = patchNode.javascriptString
        let result = jsContext.evaluateScript("""
function evaluate(inputs) {
  const strings = inputs[0];

  // Basic keyword sentiment map
  const positiveWords = ["good", "great", "love", "happy", "excellent", "awesome"];
  const negativeWords = ["bad", "hate", "sad", "terrible", "awful", "horrible"];

  const result = strings.map(s => {
    const text = s.value.toLowerCase();
    let score = 0;

    for (const word of positiveWords) {
      if (text.includes(word)) score += 1;
    }

    for (const word of negativeWords) {
      if (text.includes(word)) score -= 1;
    }

    // Normalize to -1 / 0 / 1
    const normalized = score > 0 ? 1 : score < 0 ? -1 : 0;

    return {
      value: normalized,
      value_type: "number"
    };
  });

  return [result];
}

// Get result from eval using node_inputs, which is passed from Swift land
let result = evaluate(node_inputs)

// Return result into string, which gets picked up from Swift
JSON.stringify(result)
"""
        )
        
        guard let stringResult = result?.toString() else {
            return .init(outputsValues: [[.number(.zero)]])
        }
        
        print("javascript result: \(stringResult)")
        
//        let steps = try data.getOpenAISteps()
        
        return .init(outputsValues: [[.number(.zero)]])
    }
}
