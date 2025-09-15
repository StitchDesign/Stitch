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

struct TriangleShapePatchNode: PatchNodeDefinition {
    static let patch = Patch.triangleShape
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.position(TriangleData.defaultTriangleP1)],
                    label: "First Point"
                ),
                .init(
                    defaultValues: [.position(TriangleData.defaultTriangleP2)],
                    label: "Second Point"
                ),
                .init(
                    defaultValues: [.position(TriangleData.defaultTriangleP3)],
                    label: "Third Point"
                )
            ],
            outputs: [
                .init(
                    label: "Shape",
                    type: .shape
                )
            ]
        )
    }
}

@MainActor
func triangleShapeNode(id: NodeId,
                       position: CGPoint = .zero,
                       zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("First Point", [.position(TriangleData.defaultTriangleP1)]),
        ("Second Point", [.position(TriangleData.defaultTriangleP2)]),
        ("Third Point", [.position(TriangleData.defaultTriangleP3)])
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

@MainActor
func triangleShapeEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        if let p1: StitchPosition = values[0].getPosition,
           let p2: StitchPosition = values[1].getPosition,
           let p3: StitchPosition = values[2].getPosition {

            let triangle = TriangleData(p1: p1,
                                        p2: p2,
                                        p3: p3)
            let customShape = CustomShape(.triangle(triangle))
            return .shape(customShape)
        } else {
            return .shape(.triangleShapePatchNodeDefault)
        }
    }

    return resultsMaker(inputs)(op)
}
