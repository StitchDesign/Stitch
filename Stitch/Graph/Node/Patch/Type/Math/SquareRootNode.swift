//
//  SquareRootNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit


struct SquareRootPatchNode: PatchNodeDefinition {
    static let patch = Patch.squareRoot

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
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
