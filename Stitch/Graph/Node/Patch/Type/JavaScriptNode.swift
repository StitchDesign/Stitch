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
            inputs: [.init(label: "",
                           staticType: .string,
                           canDirectlyCopyUpstreamValues: true)],
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
        let prevOutputsValuesList = node.outputs
        
        let inputValuesList: PortValuesList = node.inputsValuesList
        let aiDataFromInputs: [[StitchAIPortValue]] = inputValuesList.map { (inputValues: PortValues) -> [StitchAIPortValue] in
            // Down-version run-time PortValues to Stitch AI-supported types
            do {
                let convertedValues: [CurrentStep.PortValue] = try inputValues.convert(to: [CurrentStep.PortValue].self)
                return convertedValues.map(StitchAIPortValue.init)
            } catch {
                fatalErrorIfDebug("JS Node error: port value type not support with error: \(error.localizedDescription)")
                return [StitchAIPortValue(.number(.zero))]
            }
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
        node.patchNodeViewModel?.javaScriptDebugResult = stringResult
        
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
    
    @MainActor
    func applyJavascriptToInputsAndOutputs(response: JavaScriptNodeSettings,
                                           currentGraphTime: TimeInterval,
                                           activeIndex: ActiveIndex) {
        
        // Update the ports etc.
        let oldJavaScriptSettings = self.javaScriptNodeSettings
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
            let defaultValue = inputDefinition.strictType.defaultPortValue
            let didTypeChange = oldJavaScriptSettings?.inputDefinitions[safe: portIndex]?.strictType != inputDefinition.strictType
            
            let inputObserver = self.inputsObservers[safe: portIndex] ??
            InputNodeRowObserver(values: [defaultValue],
                                 id: .init(portId: portIndex,
                                           nodeId: self.id),
                                 upstreamOutputCoordinate: nil)
            
            // Always create new row view model to assert new type parameters
            let newRowViewModel = InputNodeRowViewModel(
                id: .init(graphItemType: .canvas(.node(self.id)),
                          nodeId: self.id,
                          portId: portIndex),
                initialValue: defaultValue,
                rowDelegate: inputObserver,
                canvasItemDelegate: self.canvasObserver)
            
            if self.inputsObservers[safe: portIndex] == nil {
                self.inputsObservers.append(inputObserver)
                self.canvasObserver.inputViewModels.append(newRowViewModel)
            }
            
            // logic needed to update values if type changed
            else if didTypeChange {
                assertInDebug(portIndex < self.canvasObserver.inputViewModels.count)
                
                // Keep existing connection
                let upstreamConneciton = inputObserver.upstreamOutputCoordinate
                
                // Update some new default value and remove connection for simplifying value coercion
                inputObserver.upstreamOutputCoordinate = nil
                
                // Specify new types for row view models
                self.canvasObserver.inputViewModels[portIndex] = newRowViewModel
                
                inputObserver.changeInputType(to: inputDefinition.strictType,
                                              nodeKind: .patch(self.patch),
                                              currentGraphTime: currentGraphTime,
                                              // TODO: update computed node state
                                              computedState: nil,
                                              activeIndex: activeIndex,
                                              isVisible: true)
                
                // Update value after field group has changed
                inputObserver.updateValuesInInput([inputDefinition.strictType.defaultPortValue])
                
                inputObserver.upstreamOutputCoordinate = upstreamConneciton
            }
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
    
    /// Upon new JavaScript code:
    /// 1. Sets script to node
    /// 2. Processes changes to inputs and outputs
    /// 3. Recalculates node
    @MainActor
    func processNewJavascript(response: JavaScriptNodeSettings,
                              document: StitchDocumentViewModel) {
        
        // Update the node title
        guard let node = document.visibleGraph.getNode(self.id) else {
            fatalErrorIfDebug()
            return
        }
        
        node.nodeTitleEdited(titleEditType: .canvas(self.canvasObserver.id),
                             edit: response.suggestedTitle,
                             isCommitting: true,
                             graph: document.visibleGraph)
        
        self.applyJavascriptToInputsAndOutputs(response: response,
                                               currentGraphTime: document.graphStepManager.graphTime,
                                               activeIndex: document.activeIndex)
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
