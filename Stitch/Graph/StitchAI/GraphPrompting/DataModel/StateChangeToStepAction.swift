//
//  StepTypeActionsFromStateChanges.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/11/24.
//

import Foundation
import SwiftyJSON
import SwiftUI

// MARK: LISTENING TO STATE CHANGES WHIE LLM-RECORDING MODE IS ACTIVE AND TURNING EACH STATE CHANGE INTO AN LLM-STEP-ACTION (i.e. `Step`)

extension StitchDocumentViewModel {
    
    // TODO: see `LLMActionUtil` methods like `maybeCreateLLMMoveNode` etc. for remaining methods that need to be converted from `LLMAction` to `LLMStepAction`
    // fka `maybeCreateLLMAddNode`
    @MainActor
    func maybeCreateStepTypeAddNode(_ newlyCreatedNodeId: NodeId) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           let newlyCreatedNode = self.graph.getNodeViewModel(newlyCreatedNodeId) {
            
            let step: LLMStepAction = newlyCreatedNode.createLLMStepAddNode()
            
            log("maybeCreateStepTypeAddNode: step: \(step)")
            
            // // DEBUG:
            //            let data: Data = try! JSONEncoder().encode(step)
            //            let json: JSON = data.toJSON!
            //            // DOES NOT INCLUDE 'NIL' FIELDS
            //            log("maybeCreateStepTypeAddNode: json: \(json)")
            
            self.llmRecording.actions.append(step)
        }
    }
    
    @MainActor
    func maybeCreateLLMStepChangeNodeType(node: NodeViewModel,
                                       newNodeType: NodeType) {
        if self.llmRecording.isRecording {
            let step = node.createLLMStepChangeNodeType(newNodeType)
            self.llmRecording.actions.append(step)
        }
    }
    
    @MainActor
    func maybeCreateLLMStepSetInput(node: NodeViewModel,
                                input: InputCoordinate,
                                value: PortValue) {
        if self.llmRecording.isRecording {
            let step = node.createLLMStepSetInput(input: input, value: value)
            self.llmRecording.actions.append(step)
        }
    }
    
    @MainActor
    func maybeCreateLLMStepEdgeAdded(fromNodeId: String,
                                     toNodeId: String, input: InputCoordinate) {
        if self.llmRecording.isRecording {
            let step = createLLMStepEdgeAdded(input: input, fromNodeId, toNodeId: toNodeId)
            self.llmRecording.actions.append(step)
        }
    }
    
    @MainActor
    func maybeCreateLLMStepAddLayerInput(_ nodeId: NodeId, _ property: LayerInputType) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           let node = self.graph.getNodeViewModel(nodeId) {

            let step = createLLMStepAddLayerInput(
                nodeId: nodeId,
                input: property.layerInput)
            
            self.llmRecording.actions.append(step)
        }
    }
}

extension NodeViewModel {
    func createLLMStepAddNode() -> LLMStepAction {
        LLMStepAction(stepType: StepType.addNode.rawValue,
                      nodeId: self.id.description, // raw string of UUID
                      nodeName: self.kind.asLLMStepNodeName)
    }
    
    func createLLMStepChangeNodeType(_ newNodeType: NodeType) -> LLMStepAction {
        LLMStepAction(stepType: StepType.changeNodeType.rawValue,
                      nodeId: self.id.description,
                      // Nov 12: Our OpenAI schema currently expects e.g. "text", not "Text"
                      nodeType: newNodeType.asLLMStepNodeType)
    }
    
    func createLLMStepSetInput(input: InputCoordinate,
                               value: PortValue) -> LLMStepAction {
        /*
         RELEVANT SECTION OF OUR OPEN-AI SCHEMA:
         
         "SetInputAction": {
           "type": "object",
           "properties": {
             "step_type": { "const": "set_input" },
             "node_id": { "type": "string", "description": "ID of the node receiving the input", "format": "uuid" },
             "value": {
               "anyOf": [
                 { "type": "number" },
                 { "type": "string" },
                 { "type": "boolean" }
               ],
               "description": "Value to set for the input"
             },
             "port": {
               "anyOf": [
                 { "type": "integer" },
                 { "$ref": "#/$defs/LayerPorts" }
               ],
               "description": "The port to which the value is set. Patch nodes use integers; Layer nodes use LayerPorts."
             },
             "node_type": { "$ref": "#/$defs/NodeType", "description": "The type of node to use." }
           },
           "required": ["step_type", "node_id", "port", "value", "node_type"]
         },
         */
        LLMStepAction(stepType: StepType.setInput.rawValue,
                      nodeId: self.id.description,
                      port: .init(value: input.asLLMStepPort()),
                      
                      // Note: `.asLLMValue: JSONFriendlyFormat` is needed for handling more complex values like `LayerDimension`
                      // value: value.asLLMValue,
                      value: .init(value: value.display),
                      
                      // For disambiguating between e.g. a string "2" and the number 2
                      nodeType: value.toNodeType.asLLMStepNodeType)
    }
}

extension InputCoordinate {
    func asLLMStepPort() -> String {
        switch self.portType {
        case .keyPath(let x):
            // Note: StitchAI does not yet support unpacked ports
            // Note 2: see our OpenAI schema for list of possible `LayerPorts`
            return x.layerInput.asLLMStepPort
        case .portIndex(let x):
            // an integer
            return x.description
        }
    }
}

//need to feed in port id's as well
//pass in the input coordinate
func createLLMStepEdgeAdded(input: InputCoordinate,
                            _ fromNodeId: String,
                            toNodeId: String) -> LLMStepAction {
    //actually create the action with the input coordiante using
    //asLLMStepPort()
    LLMStepAction(stepType: StepType.connectNodes.rawValue,
                  port: .init(value: input.asLLMStepPort()),
                  fromNodeId: fromNodeId,
                  toNodeId: toNodeId)
}


func createLLMStepAddLayerInput(nodeId: NodeId,
                                input: LayerInputPort) -> LLMStepAction {
      LLMStepAction(stepType: StepType.addLayerInput.rawValue,
                    nodeId: nodeId.description, // Don't need to specify node name?
                    port: .init(value: input.asLLMStepPort))
  }

extension LayerInputPort {
    var asLLMStepPort: String {
        self.label(useShortLabel: true)
    }
}

// `NodeType` is just typealias for `UserVisibleType`, see e.g. `UserVisibleType_V27`
extension NodeType {
    // TODO: our OpenAI schema does not define all possible node-types, and those node types that we do define use camelCase
    // TODO: some node types use human-readable strings ("Sizing Scenario"), not camelCase ("sizingScenario") as their raw value; so can't use `NodeType(rawValue:)` constructor
    var asLLMStepNodeType: String {
        self.display.toCamelCase()
    }
}

extension NodeKind {
    var asLLMStepNodeName: String {
        switch self {
        case .patch(let x):
            // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot || Patch"
            return x.defaultDisplayTitle().toCamelCase() + " || Patch"
        case .layer(let x):
            return x.defaultDisplayTitle().toCamelCase() + " || Layer"
        case .group:
            fatalErrorIfDebug("NodeKind: asLLMStepNodeName: should never create a group node with step actions")
            return ""
        }
    }
}

extension LLMStepActions {
    func asJSON() -> JSON? {
        do {
            let data = try JSONEncoder().encode(self)
            let json = try JSON(data: data)
            log("LLMStepActions: asJSON: encoded json: \(json)")
            return json
        } catch {
            log("LLMStepActions: asJSON: error: \(error)")
            return nil
        }
    }
    
    func asJSONDisplay() -> String {
        self.asJSON()?.description ?? "No LLM-Acceptable Actions Detected"
    }
}