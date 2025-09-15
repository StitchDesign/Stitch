//
//  OvalPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/21/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct OvalShapePatchNode: PatchNodeDefinition {
    static let patch = Patch.ovalShape
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.position(CGRect.defaultOval.origin)],
                    label: "Position"
                ),
                .init(
                    defaultValues: [.size(CGRect.defaultOval.size.toLayerSize)],
                    label: "Size"
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
func ovalShapeEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        let position: StitchPosition = values[0].getPosition ?? .zero
        let size: LayerSize = values[1].getSize ?? .init(width: 20, height: 20)

        // Should `size` be a LayerSize here?
        // Actually no -- `Rounded Rectangle` shape patch node's input fields
        // coerce `"auto"` to 0 and `100%` to 100.
        return .shape(CustomShape(.oval(.init(origin: position,
                                              size: size.asAlgebraicCGSize))))
    }

    return resultsMaker(inputs)(op)
}
