//
//  TrianglePatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/8/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import NonEmpty

@MainActor
func triangleShapeNode(id: NodeId,
                       position: CGSize = .zero,
                       zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("First Point", [.position(TriangleData.defaultTriangleP1.toCGSize)]),
        ("Second Point", [.position(TriangleData.defaultTriangleP2.toCGSize)]),
        ("Third Point", [.position(TriangleData.defaultTriangleP3.toCGSize)])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values:
            ("Shape", [.shape(.triangleShapePatchNodeDefault)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .triangleShape,
        inputs: inputs,
        outputs: outputs)
}

func triangleShapeEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        if let p1: StitchPosition = values[0].getPosition,
           let p2: StitchPosition = values[1].getPosition,
           let p3: StitchPosition = values[2].getPosition {

            let triangle = TriangleData(p1: p1.toCGPoint,
                                        p2: p2.toCGPoint,
                                        p3: p3.toCGPoint)
            let customShape = CustomShape(.triangle(triangle))
            return .shape(customShape)
        } else {
            return .shape(.triangleShapePatchNodeDefault)
        }
    }

    return resultsMaker(inputs)(op)
}
