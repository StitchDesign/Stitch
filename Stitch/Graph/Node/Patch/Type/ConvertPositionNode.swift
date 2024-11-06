//
//  ConvertPositionNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 3/13/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func convertPositionNode(nodeId: NodeId = NodeId(),
                         n1: Double = 0.0,
                         position: CGSize = .zero,
                         zIndex: Double = 0,
                         interactionId: PortValue = interactionIdDefault) -> PatchNode {
    let inputs = toInputs(
        id: nodeId,
        values:
            ("From Parent", [interactionId]), // 0
        ("From Anchor", [.anchoring(.defaultAnchoring)]), // 1
        ("Point", [.position(StitchPosition.zero)]), // 2
        ("To Parent", [interactionId]), // 3
        ("To Anchor", [.anchoring(.defaultAnchoring)]) // 4
    )

    let outputs = toOutputs(id: nodeId, offset: inputs.count,
                            values: (nil, [.position(.zero)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: nodeId,
        patchName: .convertPosition,
        inputs: inputs,
        outputs: outputs)
}

// Does this assume single layer?
// Preferably, retrieve the layer view model at that loop-index?
@MainActor
func convertPositionEval(node: PatchNode,
                         graphState: GraphDelegate) -> PortValuesList {

    // log("convertPositionEval: node.sortedInputsValues: \(node.inputs)")

    let defaultOpResult = PortValue.position(.zero)
    
    let op: OpWithIndex<PortValue> = { (values: PortValues, loopIndex: Int) -> PortValue in
        log("convertPositionEval: op: values: \(values)")
        
        let layerViewModelAtIndex = { (layerNodeId: LayerNodeId) -> LayerViewModel? in
            let layerNode = graphState.getNodeViewModel(layerNodeId.asNodeId)?.layerNode
            return layerNode?.previewLayerViewModels[safe: loopIndex] ?? layerNode?.previewLayerViewModels.first
        }
        
        /*
         Some complications here:
         
         The patch eval extends all inputs to be the length of the longest input. So the from-layer and to-layer inputs on the pass could individually have length 3 and 5 respectively, but we'll do 5 ops total (since 5 is longest, assuming other inputs' loops are length 1).
         
         But from-layer and to-layer refer to layers (layer nodes) that have their own inputs and loop lengths.
         The longest loop in a layer node's inputs create as many layer view models.
         
         So we could be in a situation where e.g. the from-layer's layer node only has 2 layer view model; so on eval-op loop-indices [2,3,4] (out [0, 1, 2, 3, 4] loop indices), we would not find a layer view model for the from-layer.
         
         TODO: if loop-index exceeds the length of a layer node's layer view models, grab the last item / loop around? i.e. extend the layer view model list the same way we extend inputs; but just grab the exact data needed, don't create new LayerViewModels etc.
         */
        let fromLayerId: LayerNodeId? = values[safe: 0]?.getInteractionId
        let toLayerId: LayerNodeId? = values[safe: 3]?.getInteractionId
        
        let previewWindowRect = CGRect(origin: .zero,
                                       size: graphState.previewWindowSize)
        
        let fromLayerViewModel: LayerViewModel? = fromLayerId.flatMap(layerViewModelAtIndex)
        let fromRect: CGRect = fromLayerViewModel?.readFrame ?? previewWindowRect
        let toRect: CGRect = toLayerId.flatMap(layerViewModelAtIndex)?.readFrame ?? previewWindowRect
       
        let fromScale = fromLayerViewModel?.scale.getNumber ?? .defaultScale
        
        // Note: these are inputs on the ConvertPosition patch node, not the LayerInputPort.anchoring property on the layer
        let fromAnchor: Anchoring = values[safe: 1]?.getAnchoring ?? .defaultAnchoring
        let fromInput: CGPoint = values[safe: 2]?.getPosition ?? .zero
        let toAnchor: Anchoring = values[safe: 4]?.getAnchoring ?? .defaultAnchoring
        
        let convertedPosition = convertPosition(
            fromRect: fromRect,
            fromAnchor: fromAnchor,
            fromInput: fromInput,
            fromScale: fromScale,
            toRect: toRect,
            toAnchor: toAnchor)
        
        return .position(convertedPosition)
    }
        
    //    let k = resultsMaker(node.inputs)(op)
    let newOutput = loopedEval(node: node, evalOp: op)
    return [newOutput]
}

func convertPosition(fromRect: CGRect,
                     fromAnchor: Anchoring,
                     fromInput: CGPoint,
                     fromScale: CGFloat,
                     toRect: CGRect,
                     toAnchor: Anchoring) -> CGPoint {
    
    // just taking the
    // print("\nFROM ANCHOR")
    let from: CGPoint = fromRect.getPointAtAnchor(fromAnchor)
    
    // print("\nTO ANCHOR")
    let to: CGPoint = toRect.getPointAtAnchor(toAnchor)
    
    let fromX = from.x
    let toX = to.x
    // TODO: figure out how to properly scale the `fromInput` up or down BASED ON SCALING EFFECTS FROM PARENTS IN THE HIERARCHY
    let convertedX = (fromX + (fromInput.x * fromScale)) - toX
    
    let fromY = from.y
    let toY = to.y
    let convertedY = (fromY + (fromInput.y * fromScale)) - toY
    
    return .init(x: convertedX, y: convertedY)
}


extension CGRect {
    func getPointAtAnchor(_ anchor: Anchoring) -> CGPoint {
        
        let x = self.origin.x + (self.size.width * anchor.x)
        let y = self.origin.y + (self.size.height * anchor.y)
                
        // print("getPointAtAnchor: anchor: \(anchor)")
        // print("getPointAtAnchor: origin: \(origin)")
        // print("getPointAtAnchor: size: \(size)")
        // print("getPointAtAnchor: x: \(x)")
        // print("getPointAtAnchor: y: \(y)")
        
        return .init(x: x, y: y)
    }
}
