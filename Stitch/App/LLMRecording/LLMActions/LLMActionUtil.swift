//
//  LLMActionUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import StitchSchemaKit

extension NodeViewModel {
    @MainActor
    var llmNodeTitle: String {
        // Use parens to indicate chopped off uuid
        self.displayTitle + " (" + self.id.debugFriendlyId + ")"
    }
}

extension GraphState {

    @MainActor
    func maybeCreateLLMAddLayerInput(_ nodeId: NodeId, _ property: LayerInputType) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.graphUI.llmRecording.isRecording,
           let node = self.getNodeViewModel(nodeId) {

            let addLayer = LLMAddLayerInput(
                node: node.llmNodeTitle,
                port: property.label())
            
            self.graphUI.llmRecording.actions.append(.addLayerInput(addLayer))
        }
    }
    
    @MainActor
    func maybeCreateLLMAddLayerOutput(_ nodeId: NodeId, _ portId: Int) {
                
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.graphUI.llmRecording.isRecording,
           let node = self.getNodeViewModel(nodeId) {
            
            let output = OutputCoordinate(portId: portId, nodeId: nodeId)
            let port = output.asLLMPort(nodeKind: node.kind,
                                        nodeIO: .output,
                                        nodeType: node.userVisibleType)
            
            let addLayer = LLMAddLayerInput(
                node: node.llmNodeTitle,
                port: port)
            
            self.graphUI.llmRecording.actions.append(.addLayerInput(addLayer))
        }
    }
    
    @MainActor
    func maybeCreateLLMAddNode(_ newlyCreatedNodeId: NodeId) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.graphUI.llmRecording.isRecording,
           let newlyCreatedNode = self.getNodeViewModel(newlyCreatedNodeId) {
            
            let llmAddNode = LLMAddNode(node: newlyCreatedNode.llmNodeTitle)
            
            self.graphUI.llmRecording.actions.append(.addNode(llmAddNode))
        }
    }

    @MainActor
    func maybeCreateLLMMoveNode(canvasItem: CanvasItemViewModel,
                                // (position - previousGesture) i.e. how much we moved
                                diff: CGPoint) {
        
        if self.graphUI.llmRecording.isRecording,
           let nodeId = canvasItem.nodeDelegate?.id,
           let node = self.getNode(nodeId) {
            
            let layerInput = canvasItem.id.layerInputCase?.keyPath.label()
            let layerOutPort = canvasItem.id.layerOutputCase?.portId.description
                        
            let llmMoveNode = LLMMoveNode(
                node: node.llmNodeTitle, 
                port: layerInput ?? layerOutPort ?? "",
                // Position is diff'd against a graphOffset of 0,0
                // Round the position numbers so that
                translation: .init(x: diff.x.rounded(),
                                   y: diff.y.rounded()))
            
            self.graphUI.llmRecording.actions.append(.moveNode(llmMoveNode))
        }
    }
        
    @MainActor
    func maybeCreateLLMAddEdge(_ edge: PortEdgeData) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.graphUI.llmRecording.isRecording,
           let fromNode = self.getNodeViewModel(edge.from.nodeId),
           let toNode = self.getNodeViewModel(edge.to.nodeId) {
           
            let fromOutput = edge.from.asLLMPort(nodeKind: fromNode.kind, 
                                                 nodeIO: .output,
                                                 nodeType: fromNode.userVisibleType)
            let toInput = edge.to.asLLMPort(nodeKind: toNode.kind,
                                            nodeIO: .input,
                                            nodeType: toNode.userVisibleType)
            
            self.graphUI.llmRecording.actions.append(
                .addEdge(LLMAddEdge(
                    // Need to turn the `NodeIOCoordinate` into a
                    from: .init(node: fromNode.llmNodeTitle, 
                                port: fromOutput),
                    to: .init(node: toNode.llmNodeTitle,
                              port: toInput)))
            )
        }
    }
    
    
    @MainActor
    func maybeCreateLLMSetField(node: NodeViewModel,
                                input: InputCoordinate,
                                fieldIndex: Int,
                                value: PortValue) {
        
        if self.graphUI.llmRecording.isRecording {
            
            let port = input.asLLMPort(nodeKind: node.kind,
                                       nodeIO: .input,
                                       nodeType: node.userVisibleType)
            
            self.graphUI.llmRecording.actions.append(
                .setField(LLMSetFieldAction(
                    field: LLMAFieldCoordinate(node: node.llmNodeTitle,
                                               port: port,
                                               field: fieldIndex),
                    value: value.asLLMValue,
                    nodeType: NodeType(value).display))
            )
        }
    }
    
    @MainActor
    func maybeCreateLLMSChangeNodeType(node: NodeViewModel,
                                       newNodeType: NodeType) {
        
        if self.graphUI.llmRecording.isRecording {
            self.graphUI.llmRecording.actions.append(
                .changeNodeType(LLMAChangeNodeTypeAction(
                    node: node.llmNodeTitle,
                    nodeType: newNodeType))
            )
        }
    }
    
}

extension PortValue {
    var asLLMValue: String {
        switch self {
        // Use shorter ids for assigned-layer nodes
        case .assignedLayer(let x):
            return x?.id.debugFriendlyId.description ?? self.display
        default:
            return self.display
        }
    }
}

extension NodeIOCoordinate {
    // TODO: use labels if patch node input has that?
    func asLLMPort(nodeKind: NodeKind,
                   nodeIO: NodeIO,
                   nodeType: NodeType?) -> String {
        
        switch self.portType {
        
            // If we have a LayerNode input, use that label
        case .keyPath(let x):
            return x.label()
            
            // If we have a PatchNode input/output, or LayerNode output,
            // try to find the label per node definitions
        case .portIndex(let portId):
            
            let definitions = nodeKind.rowDefinitions(for: nodeType)
            
            switch nodeIO {
            
            case .input:
                let rowLabel = definitions.inputs[safe: portId]?.label ?? ""
                return rowLabel.isEmpty ? portId.description : rowLabel
            
            case .output:
                let rowLabel = definitions.outputs[safe: portId]?.label ?? ""
                return rowLabel.isEmpty ? portId.description : rowLabel
            }
        }
    }
}
