//
//  LLMEvents.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftyJSON
import StitchSchemaKit

// Redux-events associated with LLM recording etc.

struct LLMRecordingToggled: GraphEvent {
    
    func handle(state: GraphState) {
        if state.graphUI.llmRecording.isRecording {
            state.llmRecordingEnded()
        } else {
            state.llmRecordingStarted()
        }
    }
}

extension GraphState {
    
    @MainActor
    func llmRecordingStarted() {
        self.graphUI.llmRecording.isRecording = true
        
        // Jump back to center, so the LLMMoveNde.position can be diff'd against 0,0
        self.graphMovement.localPosition = .zero
        self.graphMovement.localPreviousPosition = .zero
    }
    
    @MainActor
    func llmRecordingEnded() {
        self.graphUI.llmRecording.isRecording = false
        
        // Cache the json of the actions; else TextField changes cause constant encoding and thus json-order changes
        self.graphUI.llmRecording.promptState.actionsAsDisplayString = self.graphUI.llmRecording.actions.asJSONDisplay()
        
        // If we stopped recording and have LLMActions, show the prompt
        if !self.graphUI.llmRecording.actions.isEmpty {
            self.graphUI.llmRecording.promptState.showModal = true
            self.graphUI.reduxFocusedField = .llmModal
        }
    }
}

struct LLMActionsJSONEntryModalOpened: GraphUIEvent {
    func handle(state: GraphUIState) {
        state.llmRecording.jsonEntryState.showModal = true
        state.reduxFocusedField = .llmModal
    }
}

// When json-entry modal is closed, we turn the JSON of LLMActions into state changes
struct LLMActionsJSONEntryModalClosed: GraphEventWithResponse {
    func handle(state: GraphState) -> GraphResponse {
                
        let jsonEntry = state.graphUI.llmRecording.jsonEntryState.jsonEntry
        
        state.graphUI.llmRecording.jsonEntryState.showModal = false
        state.graphUI.llmRecording.jsonEntryState.jsonEntry = ""
        state.graphUI.reduxFocusedField = nil
        
        guard !jsonEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log("LLMActionsJSONEntryModalClosed: json entry")
            return .noChange
        }
        
        do {
            let json = JSON(parseJSON: jsonEntry) // returns null json if parsing fails
            let data = try json.rawData()
            let actions: LLMActions = try JSONDecoder().decode(LLMActions.self,
                                                               from: data)
            actions.forEach { state.handleLLMAction($0) }
            state.graphUI.llmRecording.jsonEntryState = .init() // reset
            return .shouldPersist
        } catch {
            log("LLMActionsJSONEntryModalClosed: Error: \(error)")
            fatalErrorIfDebug("LLMActionsJSONEntryModalClosed: could not retrieve")
            return .noChange
        }
    }
}

extension String {
            
    var parseLLMNodeTitleId: String? {
        self.parseLLMNodeTitle?.0
    }
    
    // e.g. for llm node title = "Power (123456)",
    // llm node id is "123456"
    // llm node kind is "Power"
    var parseLLMNodeTitle: (String, NodeKind)? {
        
        var s = self
        
        // drop closing parens
        s.removeLast()
        
        // split at and remove opening parens
        var _s = s.split(separator: "(")
        
        let llmNodeId = (_s.last ?? "").trimmingCharacters(in: .whitespaces)
        let llmNodeKind = (_s.first ?? "").trimmingCharacters(in: .whitespaces).getNodeKind
        
        if let llmNodeKind = llmNodeKind {
            return (llmNodeId, llmNodeKind)
        } else {
            log("parseLLMNodeTitle: unable to parse LLM Node Title")
            return nil
        }
    }
    
    var getNodeKind: NodeKind? {
        // Assumes `self` is already "human-readable" patch/layer name,
        // e.g. "Convert Position" not "convertPosition"
        // TODO: update Patch and Layer enums to use human-readable names for their cases' raw string values; then can just use `Patch(rawValue: self)`
        if let layer = Layer.allCases.first(where: { $0.defaultDisplayTitle() == self }) {
            return .layer(layer)
        } else if let patch = Patch.allCases.first(where: { $0.defaultDisplayTitle() == self }) {
            return .patch(patch)
        }
        
        return nil
    }
}
     
typealias LLMNodeTitleIdToNodeId = [String: NodeId]

extension GraphState {
    
    @MainActor
    func handleLLMAction(_ action: LLMAction) {
        
        log("handleLLMAction: action: \(action)")
        
        // Make sure we're not "recording", so that functions do
        self.graphUI.llmRecording.isRecording = false
                
        switch action {
            
        case .addNode(let x):
            // AddNode action has a specific "LLM action node id" i.e. node default title + part of the node id
            // ... suppose we create a node, then move it;
            // the LLM-move-action will expect the specific "LLM action
            
            if let (llmNodeId, nodeKind) = x.node.parseLLMNodeTitle,
               // We created a patch node or layer node; note that patch node is immediately added to the canvas; biut
               let nodeId = self.nodeCreated(choice: nodeKind) {
                
                self.graphUI.llmRecording.llmNodeIdMapping.updateValue(nodeId,
                                                                       forKey: llmNodeId)
            }
            
        // A patch node or layer-input-on-graph was moved
        case .moveNode(let x):
            
            if let canvasItemId = getCanvasId(
                llmNode: x.node,
                llmPort: x.port,
                self.graphUI.llmRecording.llmNodeIdMapping),
               
                // canvas item must exist
               let canvasItem = self.getCanvasItem(canvasItemId) {
                self.updateCanvasItemOnDragged(canvasItem,
                                               translation: x.translation.asCGSize)
            }
               
        case .addEdge(let x):
            
            // Both to node and from node must exist
            guard let fromNodeId = x.from.node.getNodeIdFromLLMNode(from: self.graphUI.llmRecording.llmNodeIdMapping),
                  self.getNode(fromNodeId).isDefined else  {
                log("handleLLMAction: .addEdge: No origin node")
                return
            }
            
            guard let toNodeId = x.to.node.getNodeIdFromLLMNode(from: self.graphUI.llmRecording.llmNodeIdMapping),
                  self.getNode(toNodeId).isDefined else  {
                log("handleLLMAction: .addEdge: No destination node")
                return
            }
            
            guard let fromPort: NodeIOPortType = x.from.port.parseLLMPortAsPortType else {
                log("handleLLMAction: .addEdge: No origin port")
                return
            }
            
            guard let toPort: NodeIOPortType = x.to.port.parseLLMPortAsPortType else {
                log("handleLLMAction: .addEdge: No destination port")
                return
            }
            
            let portEdgeData = PortEdgeData(
                from: .init(portType: fromPort, nodeId: fromNodeId),
                to: .init(portType: toPort, nodeId: toNodeId))
            
            self.edgeAdded(edge: portEdgeData)
            
        case .setField(let x):
            
            guard let nodeId = x.field.node.getNodeIdFromLLMNode(from: self.graphUI.llmRecording.llmNodeIdMapping),
                  let node = self.getNode(nodeId) else {
                log("handleLLMAction: .setField: No node id or node")
                return
            }
            
            guard let portType = x.field.port.parseLLMPortAsPortType else {
                log("handleLLMAction: .setField: No port")
                return
            }
            
            let inputCoordinate = InputCoordinate(portType: portType, nodeId: nodeId)
            
            guard let nodeType = x.nodeType.parseLLMNodeType else {
                log("handleLLMAction: .setField: No node type")
                return
            }
            
            guard let input = self.getInputObserver(coordinate: inputCoordinate) else {
                log("handleLLMAction: .setField: No input")
                return
            }
            
            let fieldIndex = x.field.field
            
            // The new value for that entire input, not just for some field
            guard let value: PortValue = x.value.asPortValueForLLMSetField(nodeType) else {
                log("handleLLMAction: .setField: No port value")
                return
            }
            
            node.removeIncomingEdge(at: inputCoordinate,
                                    activeIndex: self.activeIndex)
            
            input.setValuesInInput([value])
            
            
        case .changeNodeType(let x):
            
            // Node must already exist
            guard let nodeId = x.node.getNodeIdFromLLMNode(from: self.graphUI.llmRecording.llmNodeIdMapping),
                  self.getNode(nodeId).isDefined else {
                log("handleLLMAction: .changeNodeType: No node id or node")
                return
            }
            
            guard let nodeType = x.nodeType.parseLLMNodeType else {
                log("handleLLMAction: .changeNodeType: No node type")
                return
            }
            
            let _ = self.nodeTypeChanged(nodeId: nodeId, newNodeType: nodeType)

        
        case .addLayerInput(let x):
            
            // Layer node must already exist
            guard let nodeId = x.node.getNodeIdFromLLMNode(from: self.graphUI.llmRecording.llmNodeIdMapping),
                  let node = self.getNode(nodeId) else {
                log("handleLLMAction: .addLayerInput: No node id or node")
                return
            }
            
            // `.port` should be some known layer input type
            guard let layerInput = x.port.parseLLMPortAsLayerInputType else {
                log("handleLLMAction: .addLayerInput: Unknown port")
                return
            }
            
            guard let input = node.getInputRowObserver(for: .keyPath(layerInput)) else {
                log("handleLLMAction: .addLayerInput: No input for \(layerInput)")
                return
            }
            
            self.layerInputAddedToGraph(node: node,
                                        input: input,
                                        coordinate: layerInput)
            
//
//        case .addLayerOutput(let x):
//            <#code#>
//            
        default:
            fatalError()
        }
        
    }
}

// When prompt modal is closed, we write the JSON of prompt + actions to file.
struct LLMRecordingPromptClosed: GraphEvent {
    
    func handle(state: GraphState) {
        
        // log("LLMRecordingPromptClosed called")
        
        state.graphUI.llmRecording.promptState.showModal = false
        state.graphUI.reduxFocusedField = nil
        
        let actions = state.graphUI.llmRecording.actions
        
        // TODO: somehow we're getting this called twice
        guard !actions.isEmpty else {
            state.graphUI.llmRecording = .init()
            return
        }
        
        // Write the JSONL/YAML to file
        let recordedData = LLMRecordingData(actions: actions,
                                            prompt: state.graphUI.llmRecording.promptState.prompt)
        
        // log("LLMRecordingPromptClosed: recordedData: \(recordedData)")
        
        if !recordedData.actions.isEmpty {
            Task {
                do {
                    let data = try JSONEncoder().encode(recordedData)
                    
                    // need to create a directory
                    let docsURL = StitchFileManager.documentsURL.url
                    let dataCollectionURL = docsURL.appendingPathComponent(LLM_COLLECTION_DIRECTORY)
                    let filename = "\(state.projectName)_\(state.projectId)_\(Date().description).json"
                    let url = dataCollectionURL.appending(path: filename)
                    
                    // log("LLMRecordingPromptClosed: docsURL: \(docsURL)")
                    // log("LLMRecordingPromptClosed: dataCollectionURL: \(dataCollectionURL)")
                    // log("LLMRecordingPromptClosed: url: \(url)")
                    
                    // It's okay if this fails because directory already exists
                    try? FileManager.default.createDirectory(
                        at: dataCollectionURL,
                        withIntermediateDirectories: false)
                    
                    try data.write(to: url,
                                   options: [.atomic, .completeFileProtection])
                    
                    // DEBUG
                    // let input = try String(contentsOf: url)
                    // log("LLMRecordingPromptClosed: success: \(input)")
                } catch {
                    log("LLMRecordingPromptClosed: error: \(error.localizedDescription)")
                }
            }
        }
        
        // Reset LLMRecordingState
        state.graphUI.llmRecording = .init()
    }
}

struct LLMRecordingModeEnabledChanged: StitchStoreEvent {
    
    let enabled: Bool
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        log("LLMRecordingModeSet: enabled: \(enabled)")
        store.llmRecordingModeEnabled = enabled
        
        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            enabled,
            forKey: LLM_RECORDING_MODE_KEY_NAME)
        
        return .noChange
    }
}
