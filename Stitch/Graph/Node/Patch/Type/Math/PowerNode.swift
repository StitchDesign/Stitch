//
//  PowerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit


struct PowerPatchNode: PatchNodeDefinition {
    static let patch = Patch.power

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }
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
