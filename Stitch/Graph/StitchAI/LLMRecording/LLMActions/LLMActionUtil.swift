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

extension StitchDocumentViewModel {

    @MainActor
    func maybeCreateLLMAddLayerInput(_ nodeId: NodeId, _ property: LayerInputType) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           let node = self.graph.getNodeViewModel(nodeId) {

            let addLayer = LLMAddLayerInput(
                node: node.llmNodeTitle,
                port: property.layerInput.label())
            
            self.llmRecording.actions.append(.addLayerInput(addLayer))
        }
    }
    
    @MainActor
    func maybeCreateLLMAddLayerOutput(_ nodeId: NodeId, _ portId: Int) {
                
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           let node = self.graph.getNodeViewModel(nodeId) {
            
            let output = OutputCoordinate(portId: portId, nodeId: nodeId)
            let port = output.asLLMPort(nodeKind: node.kind,
                                        nodeIO: .output,
                                        nodeType: node.userVisibleType)
            
            let addLayer = LLMAddLayerOutput(
                node: node.llmNodeTitle,
                port: port)
            
            self.llmRecording.actions.append(.addLayerOutput(addLayer))
        }
    }
    
    @MainActor
        func maybeCreateLLMAddNode(_ newlyCreatedNodeId: NodeId) {
            // If we're LLM-recording, add an `LLMAddNode` action
            if self.llmRecording.isRecording,
               let newlyCreatedNode = self.graph.getNodeViewModel(newlyCreatedNodeId) {
                
                let llmAddNode = LLMAddNode(node: newlyCreatedNode.llmNodeTitle)
                
                self.llmRecording.actions.append(.addNode(llmAddNode))
            }
        }

    @MainActor
    func maybeCreateLLMMoveNode(canvasItem: CanvasItemViewModel,
                                // (position - previousGesture) i.e. how much we moved
                                diff: CGPoint) {
        
        if self.llmRecording.isRecording,
           let nodeId = canvasItem.nodeDelegate?.id,
           let node = self.graph.getNode(nodeId) {
            
            let layerInput = canvasItem.id.layerInputCase?.keyPath.layerInput.label()
            let layerOutPort = canvasItem.id.layerOutputCase?.portId.description
                        
            let llmMoveNode = LLMMoveNode(
                node: node.llmNodeTitle, 
                port: layerInput ?? layerOutPort ?? "",
                // Position is diff'd against a graphOffset of 0,0
                // Round the position numbers so that
                translation: .init(x: diff.x.rounded(),
                                   y: diff.y.rounded()))
            
            self.llmRecording.actions.append(.moveNode(llmMoveNode))
        }
    }
        
    @MainActor
    func maybeCreateLLMAddEdge(_ edge: PortEdgeData) {
        // If we're LLM-recording, add an `LLMAddNode` action
        if self.llmRecording.isRecording,
           let fromNode = self.graph.getNodeViewModel(edge.from.nodeId),
           let toNode = self.graph.getNodeViewModel(edge.to.nodeId) {
           
            let fromOutput = edge.from.asLLMPort(nodeKind: fromNode.kind, 
                                                 nodeIO: .output,
                                                 nodeType: fromNode.userVisibleType)
            let toInput = edge.to.asLLMPort(nodeKind: toNode.kind,
                                            nodeIO: .input,
                                            nodeType: toNode.userVisibleType)
            
            self.llmRecording.actions.append(
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
    func maybeCreateLLMSetInput(node: NodeViewModel,
                                input: InputCoordinate,
                                value: PortValue) {
        
        if self.llmRecording.isRecording {
            
            let port = input.asLLMPort(nodeKind: node.kind,
                                       nodeIO: .input,
                                       nodeType: node.userVisibleType)
            
            self.llmRecording.actions.append(
                .setInput(LLMSetInputAction(
                    field: LLMPortCoordinate(node: node.llmNodeTitle,
                                             port: port),
                    value: value.asLLMValue,
                    nodeType: NodeType(value).display)))
        }
    }
    
    @MainActor
    func maybeCreateLLMSChangeNodeType(node: NodeViewModel,
                                       newNodeType: NodeType) {
        
        if self.llmRecording.isRecording {
            self.llmRecording.actions.append(
                .changeNodeType(LLMAChangeNodeTypeAction(
                    node: node.llmNodeTitle,
                    nodeType: newNodeType.display))
            )
        }
    }
}

