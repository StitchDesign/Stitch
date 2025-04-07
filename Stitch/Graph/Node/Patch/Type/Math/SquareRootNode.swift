//
//  SquareRootNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func squareRootNode(id: NodeId,
                    n: Double = 1,
                    position: CGPoint = .zero,
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
        patchName: .squareRoot,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func squareRootEval(inputs: PortValuesList,
                    evalKind: MathNodeType) -> PortValuesList {

    //    log("squareRootEval called")

    let numberOp: Operation = { (values: PortValues) -> PortValue in
        //        log("squareRootEval: values: \(values)")
        let n = values[safe: 0]?.getNumber ?? .multiplicationIdentity
        let squareRoot: Double = sqrt(n)
        return .number(squareRoot)
    }

    let sizeOp: Operation = { (values: PortValues) -> PortValue in
        //        log("squareRootEval: values: \(values)")
        let n = values[safe: 0]?.getSize?.asAlgebraicCGSize ?? .multiplicationIdentity
        return .size(.init(
                        width: sqrt(n.width),
                        height: sqrt(n.height)))
    }

    let positionOp: Operation = { (values: PortValues) -> PortValue in
        //        log("squareRootEval: values: \(values)")
        let n = values[safe: 0]?.getPosition ?? .multiplicationIdentity
        return .position(.init(
                            x: sqrt(n.x),
                            y: sqrt(n.y)))
    }

    let point3DOp: Operation = { (values: PortValues) -> PortValue in
        //        log("squareRootEval: values: \(values)")
        let n = values[safe: 0]?.getPoint3D ?? .multiplicationIdentity
        return .point3D(.init(
                            x: sqrt(n.x),
                            y: sqrt(n.y),
                            z: sqrt(n.z)))
    }

    let result = resultsMaker(inputs)

    switch evalKind {
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
