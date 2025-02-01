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
           !self.llmRecording.isApplyingActions,
           let newlyCreatedNode = self.graph.getNodeViewModel(newlyCreatedNodeId),
           let patchOrLayer: PatchOrLayer = PatchOrLayer.from(nodeKind: newlyCreatedNode.kind) {

            self.llmRecording.actions.append(.addNode(.init(nodeId: newlyCreatedNodeId, nodeName: patchOrLayer)))
        }
    }
    
    @MainActor
    func maybeCreateLLMStepChangeNodeType(node: NodeViewModel,
                                          newNodeType: NodeType) {
        if self.llmRecording.isRecording,
           !self.llmRecording.isApplyingActions {
            self.llmRecording.actions.append(.changeNodeType(.init(nodeId: node.id, nodeType: newNodeType)))
        }
    }
    
    @MainActor
    func maybeCreateLLMStepSetInput(node: NodeViewModel,
                                    input: InputCoordinate,
                                    value: PortValue) {
        if self.llmRecording.isRecording,
           !self.llmRecording.isApplyingActions {
            self.llmRecording.actions.append(.setInput(
                .init(nodeId: node.id,
                      port: input.portType,
                      value: value,
                      nodeType: value.toNodeType)))
        }
    }
    
    @MainActor
    func maybeCreateLLMStepConnectionAdded(input: InputCoordinate,
                                           output: OutputCoordinate) {
            
        log("maybeCreateLLMStepConnectionAdded: input: \(input)")
        log("maybeCreateLLMStepConnectionAdded: output: \(output)")
        if self.llmRecording.isRecording,
           !self.llmRecording.isApplyingActions {
                        
            self.llmRecording.actions.append(.connectNodes(.init(
                port: input.portType,
                toNodeId: input.nodeId,
                fromPort: output.portType,
                fromNodeId: output.nodeId)))
        }
    }
    
    @MainActor
    func maybeCreateLLMStepAddLayerInput(_ nodeId: NodeId, _ property: LayerInputType) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           !self.llmRecording.isApplyingActions {

            let step = StepTypeAction.addLayerInput(.init(nodeId: nodeId, port: property.layerInput))
                        
            self.llmRecording.actions.append(step)
        }
    }
}

extension NodeIOPortType {
    func asLLMStepPort() -> String {
        switch self {
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

extension InputCoordinate {
    func asLLMStepPort() -> String {
        self.portType.asLLMStepPort()
    }
}

extension OutputCoordinate {
    func asLLMStepFromPort() -> Int {
        switch self.portType {
        case .keyPath(let x):
            fatalErrorIfDebug()
            return 0
        case .portIndex(let x):
            // an integer
            return x
        }
    }
}

//need to feed in port id's as well
//pass in the input coordinate
func createLLMStepConnectionAdded(input: InputCoordinate,
                                  output: OutputCoordinate) -> LLMStepAction {
    //actually create the action with the input coordiante using
    //asLLMStepPort()
    
    assertInDebug(output.portId.isDefined)
    
    let fromNodeString = output.nodeId.uuidString
    let toNodeString = input.nodeId.uuidString
    
    return LLMStepAction(
        stepType: StepType.connectNodes.rawValue,
        port: .init(value: input.asLLMStepPort()),
        fromPort: .init(value: String(output.asLLMStepFromPort())), 
        fromNodeId: fromNodeString,
        toNodeId: toNodeString)
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

extension [StepTypeAction] {
    func asJSON() -> JSON? {
        do {
            let data = try JSONEncoder().encode(self)
            let json = try JSON(data: data)
            log("[StepTypeAction]: asJSON: encoded json: \(json)")
            return json
        } catch {
            log("[StepTypeAction]: asJSON: error: \(error)")
            return nil
        }
    }
    
    func asJSONDisplay() -> String {
        self.asJSON()?.description ?? "No LLM-Acceptable Actions Detected"
    }
}
