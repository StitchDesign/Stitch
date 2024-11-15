//
//  LLM_ACTIONS_TO_ADD_LATER.swift
//  Stitch
//
//  Created by Nicholas Arner on 11/14/24.
//

import Foundation


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



//// MARK: Move Node
//
//struct LLMMoveNodeTranslation: Equatable, Codable {
//    let x: CGFloat
//    let y: CGFloat
//
//    var asCGSize: CGSize {
//        .init(width: x, height: y)
//    }
//}
//
//struct LLMMoveNode: Equatable, Codable {
//    var action: String = LLMActionNames.moveNode.rawValue
//    let node: String
//
//    // empty string = we moved a patch node,
//    // non-empty string = we moved a layer input/output/field
//    // Non-empty Strings always represents LABELS
//    let port: String
//
//    // (position at end of movement - position at start of movement)
//    let translation: LLMMoveNodeTranslation
//}
