//
//  RunningTotalNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

// TODO: handle more node types
@MainActor
func runningTotalNode(id: NodeId,
                      position: CGSize = .zero,
                      zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [.number(0)]) // 0
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(0)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .runningTotal,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func runningTotalEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    // (loop) -> loop
    // func runningTotalEval(inputs: PortValuesList,
    //                      evalKind: ArithmeticNodeType) -> PortValuesList {

    // An interesting op:
    // input loop: [1, 2, 3, 4, 5]
    // return output loop: [0, 1, 3, 6, 10]
    // ie value at index n = 0...(n-1).sum

    let inputLoop: PortValues = inputs.first!

    var outputLoop = PortValues()

    for index in inputLoop.indices {
        // the subRange of values we'll sum
        let subRange: PortValues = Array(inputLoop[inputLoop.startIndex..<index])
        // TODO: switch on the ArithmeticNodeType evalKind here
        let sumAtIndex: PortValue = AddEvalOps.numberOperation(subRange)
        outputLoop.append(sumAtIndex)
    }

    return [outputLoop]

    //    let result = resultsMaker(inputs)
    //
    //    switch evalKind {
    //    case .number:
    //        return result(AddEvalOperations.numberOperation)
    //    case .string:
    //        return result(AddEvalOperations.stringOperation)
    //    case .size:
    //        return result(AddEvalOperations.sizeOperation)
    //    case .position:
    //        return result(AddEvalOperations.positionOperation)
    //    case .point3D:
    //        return result(AddEvalOperations.point3DOperation)
    //    }

}
