//
//  TanNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Numerics

@MainActor
func arcTan2Node(id: NodeId,
                 y: Double = 0.0,
                 x: Double = 0.0,
                 position: CGSize = .zero,
                 zIndex: Double = 0,
                 yLoop: PortValues? = nil,
                 xLoop: PortValues? = nil) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Y", yLoop ?? [.number(y)]),
        ("X", xLoop ?? [.number(x)]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.number(atan2(y, x)
                                .radiansToDegrees
                                .rounded(toPlaces: 5))]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .arcTan2,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func arcTan2Eval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        if let y = values.first?.getNumber,
           let x = values[1].getNumber {
            return .number(atan2(y, x)
                            .radiansToDegrees
                            .rounded(toPlaces: 5))
        }

        fatalErrorIfDebug()
        return .number(.zero)
    }

    return resultsMaker(inputs)(op)
}
