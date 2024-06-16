//
//  LengthNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func lengthNode(id: NodeId,
                n: Double = 1,
                position: CGSize = .zero,
                zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(abs(n))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .length,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

func lengthEval(inputs: PortValuesList,
                evalKind: ArithmeticNodeType) -> PortValuesList {
    // log("lengthEval called")

    let stringOp: Operation = { (_: PortValues) -> PortValue in
        return .string(.init(""))
    }

    let sizeOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[0].getSize!.asAlgebraicCGSize
        let length: Double = hypot(n.width, n.height)
        return .number(length)
    }

    let positionOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[0].getPosition!
        let length: Double = hypot(n.width, n.height)
        return .number(length)
    }

    let point3DOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[0].getPoint3D!
        let length: Double = hypot(n.x, n.y)
        return .number(length)
    }

    // Length on a .number type does nothing ?
    let numberOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[0].getNumber!
        return .number(n)
    }

    let result = resultsMaker(inputs)

    switch evalKind {
    case .string:
        return result(stringOp)
    case .number:
        return result(numberOp)
    case .position:
        return result(positionOp)
    case .size:
        return result(sizeOp)
    case .point3D:
        return result(point3DOp)
    }
}
