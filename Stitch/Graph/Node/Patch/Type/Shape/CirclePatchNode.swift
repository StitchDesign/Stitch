//
//  CirclePatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/21/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func circleShapeNode(id: NodeId,
                     position: CGSize = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let circle = CGRect.defaultCircle

    let inputs = toInputs(
        id: id,
        values:
            ("Position", [.position(circle.origin)]),
        // width = diameter = radius * 2
        ("Radius", [.number(circle.size.width/2)])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values:
            ("Shape", [.shape(CustomShape(.circle(circle)))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .circleShape,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func circleShapeEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        let position: StitchPosition = values[0].getPosition ?? .zero
        let radius: Double = values[1].getNumber ?? 10.0

        let circle = CGRect(origin: position,
                            // radius = 1/2 diameter = 1/2 height or width
                            size: .init(width: radius * 2,
                                        height: radius * 2))

        return .shape(CustomShape(.circle(circle)))
    }

    return resultsMaker(inputs)(op)
}
