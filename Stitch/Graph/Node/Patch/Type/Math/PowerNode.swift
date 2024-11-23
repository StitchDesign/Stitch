//
//  PowerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func powerNode(id: NodeId,
               n: Double = 1,
               n2: Double = 0,
               position: CGSize = .zero,
               zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n)]),
        (nil, [.number(n2)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(pow(n, n2))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .power,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func powerEval(inputs: PortValuesList,
               evalKind: MathNodeType) -> PortValuesList {

    //    log("powerEval called")

    let numberOp: Operation = { (values: PortValues) -> PortValue in
        //        log("powerEval: values: \(values)")
        let n = values[0].getNumber ?? .multiplicationIdentity
        let n2 = values[1].getNumber ?? .multiplicationIdentity
        let power: Double = pow(n, n2)
        return .number(power)
    }

    let positionOp: Operation = { (values: PortValues) -> PortValue in
        //        log("powerEval: values: \(values)")
        let n = values[0].getPosition ?? .multiplicationIdentity
        let n2 = values[1].getPosition ?? .multiplicationIdentity
        return .position(.init(
                            x: pow(n.x, n2.x),
                            y: pow(n.y, n2.y)))
    }

    let sizeOp: Operation = { (values: PortValues) -> PortValue in
        //        log("powerEval: values: \(values)")
        let n = (values[0].getSize ?? .multiplicationIdentity).asAlgebraicCGSize
        let n2 = (values[1].getSize ?? .multiplicationIdentity).asAlgebraicCGSize
        return .size(.init(
                        width: pow(n.width, n2.width),
                        height: pow(n.height, n2.height)))
    }

    let point3DOp: Operation = { (values: PortValues) -> PortValue in
        //        log("powerEval: values: \(values)")
        let n = values[0].getPoint3D ?? .multiplicationIdentity
        let n2 = values[1].getPoint3D ?? .multiplicationIdentity
        return .point3D(.init(
                            x: pow(n.x, n2.x),
                            y: pow(n.y, n2.y),
                            z: pow(n.z, n2.z)))
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
