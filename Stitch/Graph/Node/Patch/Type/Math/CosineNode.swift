//
//  CoSinNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Numerics

@MainActor
func cosineNode(id: NodeId,
                n: Double = 0.0,
                position: CGPoint = .zero,
                zIndex: Double = 0,
                nLoop: PortValues? = nil) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Angle", nLoop ?? [.number(n)]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [
            .number(cos(n.degreesToRadians).rounded(toPlaces: 5))
        ])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .cosine,
        inputs: inputs,
        outputs: outputs)
}

// Swift `cos(n)` expects RADIANS;
// but Origami `angle` is in DEGREES
@MainActor
func cosineEval(inputs: PortValuesList,
                outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        if let angle = values.first?.getNumber {
            return .number(
                cos(angle.degreesToRadians)
                    .rounded(toPlaces: 5))
        }

        #if DEBUG
        fatalError()
        #endif
        return .number(.zero)
    }

    return resultsMaker(inputs)(op)
}
