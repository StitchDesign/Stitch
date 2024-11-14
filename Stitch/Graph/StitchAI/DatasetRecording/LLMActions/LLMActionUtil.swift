//
//  LLMActionUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON

extension NodeViewModel {
    @MainActor
    var llmNodeTitle: String {
        // Use parens to indicate chopped off uuid
        self.displayTitle + " (" + self.id.debugFriendlyId + ")"
    }
}

extension StitchDocumentViewModel {
    
    // TODO: OPEN AI SCHEMA: ADD LAYER OUTPUTS TO CANVAS
    //    @MainActor
    //    func maybeCreateLLMAddLayerOutput(_ nodeId: NodeId, _ portId: Int) {
    //
    //        // If we're LLM-recording, add an `LLMAddNode` action
    //        if self.llmRecording.isRecording,
    //           let node = self.graph.getNodeViewModel(nodeId) {
    //
    //            let output = OutputCoordinate(portId: portId, nodeId: nodeId)
    //            let port = output.asLLMPort(nodeKind: node.kind,
    //                                        nodeIO: .output,
    //                                        nodeType: node.userVisibleType)
    //
    //            let addLayer = LLMAddLayerOutput(
    //                node: node.llmNodeTitle,
    //                port: port)
    //
    //            // TODO: NOV 11
    ////            self.llmRecording.actions.append(.addLayerOutput(addLayer))
    //        }
    //    }
    
    
//    
//    // TODO: OPEN AI SCHEMA: MOVE NODE ON CANVAS
//    @MainActor
//    func maybeCreateLLMMoveNode(canvasItem: CanvasItemViewModel,
//                                // (position - previousGesture) i.e. how much we moved
//                                diff: CGPoint) {
//        
//        if self.llmRecording.isRecording,
//           let nodeId = canvasItem.nodeDelegate?.id,
//           let node = self.graph.getNode(nodeId) {
//            
//            let layerInput = canvasItem.id.layerInputCase?.keyPath.layerInput.label()
//            let layerOutPort = canvasItem.id.layerOutputCase?.portId.description
//                        
//            let llmMoveNode = LLMMoveNode(
//                node: node.llmNodeTitle, 
//                port: layerInput ?? layerOutPort ?? "",
//                // Position is diff'd against a graphOffset of 0,0
//                // Round the position numbers so that
//                translation: .init(x: diff.x.rounded(),
//                                   y: diff.y.rounded()))
//            
//            // TODO: NOV 11
//            // self.llmRecording.actions.append(.moveNode(llmMoveNode))
//        }
//    }
}
