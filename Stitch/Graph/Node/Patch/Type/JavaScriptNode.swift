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
              let patchNode = node.patchNodeViewModel,
              let script = patchNode.javaScriptNodeSettings?.script else {
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
        let result = jsContext.evaluateScript("""
\(script)
// Get result from eval using node_inputs, which is passed from Swift land
let result = evaluate(node_inputs)

// Return result into string, which gets picked up from Swift
JSON.stringify(result)
"""
        )
        
        guard let stringResult = result?.toString(),
              let dataResult = stringResult.data(using: .utf8) else {
            return .init(outputsValues: [[.number(.zero)]])
        }
        print("javascript result: \(stringResult)")
        
        do {
            let aiDecodedResults = try getStitchDecoder().decode([[Step]].self,
                                                                 from: dataResult)
            let outputValuesList = PortValuesList(javaScriptNodeResult: aiDecodedResults)
            return .init(outputsValues: outputValuesList)
        } catch {
            print("JavaScript node decoding error: \(error.localizedDescription)")
            return .init(outputsValues: [[.number(.zero)]])
        }
    }
}

// TODO: move to existing v32 in PatchNodeEntity SSK
struct JavaScriptNodeSettings: Hashable {
    let script: String
    let inputLabels: [String]
    let outputLabels: [String]
    
    init?(from aiStep: Step) {
        guard let script = aiStep.script,
              let inputLabels = aiStep.inputLabels,
              let outputLabels = aiStep.outputLabels else {
            // TODO: error here
            print("JavaScript node: unable extract all requested data from: \(aiStep)")
            return nil
        }
        
        self.script = script
        self.inputLabels = inputLabels
        self.outputLabels = outputLabels
    }
}

extension PortValuesList {
    init(javaScriptNodeResult: [[Step]]) {
        self = javaScriptNodeResult.map { outputResults in
            outputResults.compactMap { aiDecodedResult in
                aiDecodedResult.value
            }
        }
    }
}

extension PatchNodeViewModel {
    /// Upon new JavaScript code:
    /// 1. Sets script to node
    /// 2. Processes changes to inputs and outputs
    /// 3. Recalculates node
    @MainActor
    func processNewJavascript(response: JavaScriptNodeSettings,
                              graph: GraphState) {
        let newJavaScriptSettings = response
        self.javaScriptNodeSettings = response
        
        // Calculate node
        graph.scheduleForNextGraphStep(self.id)
        
        // Determine ports to remove
        if self.inputsObservers.count > newJavaScriptSettings.inputLabels.count {
            self.inputsObservers = self.inputsObservers.dropLast(self.inputsObservers.count - newJavaScriptSettings.inputLabels.count)
        }
        if self.outputsObservers.count > newJavaScriptSettings.outputLabels.count {
            self.outputsObservers = self.outputsObservers.dropLast(self.outputsObservers.count - newJavaScriptSettings.outputLabels.count)
        }
        
        // Create new observers if necessary
        newJavaScriptSettings.inputLabels.enumerated().forEach { portIndex, label in
            if self.inputsObservers[safe: portIndex] == nil {
                let newObserver = InputNodeRowObserver(values: [.string(.init(""))],
                                                       id: .init(portId: portIndex,
                                                                 nodeId: self.id),
                                                       upstreamOutputCoordinate: nil)
                self.inputsObservers.append(newObserver)
            }
        }
        
        newJavaScriptSettings.outputLabels.enumerated().forEach { portIndex, label in
            if self.outputsObservers[safe: portIndex] == nil {
                let newObserver = OutputNodeRowObserver(values: [.string(.init(""))],
                                                        id: .init(portId: portIndex,
                                                                  nodeId: self.id))
                self.outputsObservers.append(newObserver)
            }
        }
        
        // Saves information and determines if graph data needs to be updated
        graph.encodeProjectInBackground()
    }
}
