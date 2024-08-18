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
            ("From Parent", [interactionId]),
        ("From Anchor", [.anchoring(.defaultAnchoring)]),
        ("Point", [.position(StitchPosition.zero)]),
        ("To Parent", [interactionId]),
        ("To Anchor", [.anchoring(.defaultAnchoring)])
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

@MainActor
func convertPositionEval(node: PatchNode,
                         graphState: GraphDelegate) -> PortValuesList {

    // log("convertPositionEval: node.sortedInputsValues: \(node.inputs)")

    let positionOp: Operation = { (values: PortValues) -> PortValue in

        // log("convertPositionEval: positionOp: values: \(values)")

        var fromLayerSize: LayerSize

        if let fromLayerInputValue = values[safe: 0],
           let fromLayerId = fromLayerInputValue.getInteractionId,
           let fromNode = graphState.getNodeViewModel(fromLayerId.id),
           let layerNode = fromNode.layerNode {
            fromLayerSize = layerNode.layerSize(graphState.activeIndex) ?? .zero
        } else {
            fromLayerSize = graphState.previewWindowSize.toLayerSize
        }

        let fromLayerCGSize: CGSize = fromLayerSize.asCGSize ?? .zero

        let fromAnchor = values[safe: 1]?.getAnchoring ?? .defaultAnchoring

        let fromAnchorPosition = getAnchorPoint(
            size: fromLayerCGSize,
            anchor: fromAnchor)

        // Point
        let fromLayerPoint = values[safe: 2]?.getPosition ?? .zero

        // "To" Layer
        var toLayerSize: LayerSize

        if let toLayerInputValue = values[safe: 3],
           let toLayerId = toLayerInputValue.getInteractionId,
           let toLayerNode = graphState.getNodeViewModel(toLayerId.id)?.layerNode {
            toLayerSize = toLayerNode.layerSize(graphState.activeIndex) ?? .zero
        } else {
            toLayerSize = graphState.previewWindowSize.toLayerSize
        }

        let toLayerCGSize: CGSize = toLayerSize.asCGSize ?? .zero

        let toAnchor = values[safeIndex: 4]?.getAnchoring ?? .defaultAnchoring

        let toAnchorPosition = getAnchorPoint(
            size: toLayerCGSize,
            anchor: toAnchor)

        let result: StitchPosition = (fromAnchorPosition + fromLayerPoint) - toAnchorPosition
        return .position(result)
    }

    let k = resultsMaker(node.inputs)(positionOp)

    return k
}

/*
 The point where the anchor rests on the layer.

 Examples:
 - size = 200x200 and anchor = top-left, so we return 0,0
 - size = 200x200 and anchor = bottom-right, so we return 200,200
 - size = 200x200 and anchor = bottom-left, so we return 0,200
 - size = 200x200 and anchor = top-right, so we return 200,0

 - size = 200x200 and anchor = center, so we return 100,100
 - size = 200x200 and anchor = center-left, so we return 0,100
 - size = 200x200 and anchor = center-right, so we return 200,100
 */

func getAnchorPoint(size: CGSize,
                    anchor: Anchoring) -> CGPoint {

    switch anchor {
    case .topLeft:
        return .init(x: 0, y: 0)
    case .topCenter:
        return .init(x: size.width/2,
                     y: 0)
    case .topRight:
        return .init(x: size.width, y: 0)
    case .bottomRight:
        return .init(x: size.width,
                     y: size.height)
    case .bottomLeft:
        return .init(x: 0,
                     y: size.height)
    case .centerCenter:
        return .init(x: size.width/2,
                     y: size.height/2)
    case .centerLeft:
        return .init(x: 0,
                     y: size.height/2)
    case .centerRight:
        return .init(x: size.width,
                     y: size.height/2)
    case .bottomCenter:
        return .init(x: size.width/2,
                     y: 0)
    default:
        fatalError()
    }
}
