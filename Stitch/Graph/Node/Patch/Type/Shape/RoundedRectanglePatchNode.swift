//
//  RoundedRectanglePatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/21/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct RoundedRectangleShapePatchNode: PatchNodeDefinition {
    static let patch = Patch.roundedRectangleShape
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.position(CGRect.defaultRoundedRectangle.rect.origin)],
                    label: "Position"
                ),
                .init(
                    defaultValues: [.size(CGRect.defaultRoundedRectangle.rect.size.toLayerSize)],
                    label: "Size"
                ),
                .init(
                    defaultValues: [.number(CGRect.defaultRoundedRectangle.cornerRadius)],
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
func roundedRectangleShapeEval(inputs: PortValuesList,
                               outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        let position: StitchPosition = values[0].getPosition ?? .zero
        let size: LayerSize = values[1].getSize ?? .init(width: 100, height: 100)
        let cornerRadius: Double = values[2].getNumber ?? 4

        let rect = RoundedRectangleData(
            rect: .init(origin: position,
                        size: size.asAlgebraicCGSize),
            cornerRadius: cornerRadius)

        return .shape(CustomShape(.rectangle(rect)))
    }

    return resultsMaker(inputs)(op)
}
