//
//  CirclePatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/21/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CircleShapePatchNode: PatchNodeDefinition {
    static let patch = Patch.circleShape
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.position(CGRect.defaultCircle.origin)],
                    label: "Position"
                ),
                .init(
                    defaultValues: [.number(CGRect.defaultCircle.size.width/2)],
                    label: "Radius"
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
