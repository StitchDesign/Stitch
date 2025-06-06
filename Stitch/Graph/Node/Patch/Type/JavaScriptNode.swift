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
            inputs: [.init(label: "", staticType: .string)],
            outputs: []
        )
    }
    
    @MainActor
    static func evaluate(node: NodeViewModel) -> EvalResult? {
        // 1. Create a context
        guard let jsContext = JSContext(),
              let patchNode = node.patchNodeViewModel else {
            fatalErrorIfDebug()
            return .init(outputsValues: [])
        }
        
        guard let jsSettings = patchNode.javaScriptNodeSettings else {
            return .init(outputsValues: [])
        }

        // Construct inputs into JSON
        let inputValuesList = node.inputsValuesList
        let prevOutputsValuesList = node.outputs
        let aiDataFromInputs = inputValuesList.map { inputValues in
            inputValues.map(StitchAIPortValue.init)
        }
        
        // Encode ➜ JSON ➜ Foundation object ➜ JS
        guard let data = try? JSONEncoder().encode(aiDataFromInputs),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {   // [String: Any]
            fatalErrorIfDebug()
            return .init(outputsValues: [])
        }
        
        jsContext.setObject(jsonObject, forKeyedSubscript: "node_inputs" as NSString)
        
        // 3. Evaluate a script
        let result = jsContext.evaluateScript("""
\(jsSettings.script)
// Get result from eval using node_inputs, which is passed from Swift land
let result = evaluate(node_inputs)

// Return result into string, which gets picked up from Swift
JSON.stringify(result)
"""
        )
        
        guard let stringResult = result?.toString(),
              let dataResult = stringResult.data(using: .utf8) else {
            return .init(outputsValues: [])
        }
        print("javascript result: \(stringResult)")
        
        do {
            let aiDecodedResults = try getStitchDecoder().decode([[StitchAIPortValue]].self,
                                                                 from: dataResult)
            let outputValuesList = try PortValuesList(javaScriptNodeResult: aiDecodedResults)
            return .init(outputsValues: outputValuesList)
        } catch {
            print("JavaScript node decoding error: \(error.localizedDescription)")
            return .init(outputsValues: prevOutputsValuesList)
        }
    }
}

extension PortValuesList {
    init(javaScriptNodeResult: [[StitchAIPortValue]]) throws {
        self = try javaScriptNodeResult.map { outputResults in
            try outputResults.map { aiDecodedResult -> PortValue in
                let value = aiDecodedResult.value
                
                // Uses SSK migration to make AI's schema type migrate to the runtime's possibly newer version
                let migratedValue = try PortValueVersion
                    .migrate(entity: value,
                             version: CurrentStep.documentVersion)
                
                return migratedValue
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
    func processNewJavascript(response: JavaScriptNodeSettings) {
        let newJavaScriptSettings = response
        self.javaScriptNodeSettings = response
        
        // Determine ports to remove
        if self.inputsObservers.count > newJavaScriptSettings.inputDefinitions.count {
            let countToRemove = self.inputsObservers.count - newJavaScriptSettings.inputDefinitions.count
            self.inputsObservers = self.inputsObservers.dropLast(countToRemove)
            self.canvasObserver.inputViewModels = self.canvasObserver.inputViewModels.dropLast(countToRemove)
        }
        if self.outputsObservers.count > newJavaScriptSettings.outputDefinitions.count {
            let countToRemove = self.outputsObservers.count - newJavaScriptSettings.outputDefinitions.count
            self.outputsObservers = self.outputsObservers.dropLast(countToRemove)
            self.canvasObserver.outputViewModels = self.canvasObserver.outputViewModels.dropLast(countToRemove)
        }
        
        // Create new observers if necessary
        newJavaScriptSettings.inputDefinitions.enumerated().forEach { portIndex, inputDefinition in
            guard let inputObserver = self.inputsObservers[safe: portIndex] else {
                let defaultValue = inputDefinition.strictType.defaultPortValue
                
                let newObserver = InputNodeRowObserver(values: [defaultValue],
                                                       id: .init(portId: portIndex,
                                                                 nodeId: self.id),
                                                       upstreamOutputCoordinate: nil)
                let newRowViewModel = InputNodeRowViewModel(
                    id: .init(graphItemType: .canvas(.node(self.id)),
                              nodeId: self.id,
                              portId: portIndex),
                    initialValue: defaultValue,
                    rowDelegate: newObserver,
                    canvasItemDelegate: self.canvasObserver)
                
                self.inputsObservers.append(newObserver)
                self.canvasObserver.inputViewModels.append(newRowViewModel)
                return
            }
            
            // Update some new default value and remove connection for simplifying value coercion
            inputObserver.upstreamOutputCoordinate = nil
            inputObserver.updateValuesInInput([inputDefinition.strictType.defaultPortValue])
        }
        
        newJavaScriptSettings.outputDefinitions.enumerated().forEach { portIndex, outputDefinition in
            if self.outputsObservers[safe: portIndex] == nil {
                let defaultValue = outputDefinition.strictType.defaultPortValue
                let newObserver = OutputNodeRowObserver(values: [defaultValue],
                                                        id: .init(portId: portIndex,
                                                                  nodeId: self.id))
                
                let newRowViewModel = OutputNodeRowViewModel(
                    id: .init(graphItemType: .canvas(.node(self.id)),
                              nodeId: self.id,
                              portId: portIndex),
                    initialValue: defaultValue,
                    rowDelegate: newObserver,
                    canvasItemDelegate: self.canvasObserver)
                
                self.outputsObservers.append(newObserver)
                self.canvasObserver.outputViewModels.append(newRowViewModel)
            }
        }
    }
}

extension JavaScriptPortDefinition {
    init(_ portDefinition: JavaScriptPortDefinitionAI) throws {
        let migratedNodeType = try NodeTypeVersion
            .migrate(entity: portDefinition.strict_type,
                     version: CurrentStep.documentVersion)
        
        self.init(label: portDefinition.label,
                  strictType: migratedNodeType)
    }
}
