//
//  OvalPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/21/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func ovalShapeNode(id: NodeId,
                   position: CGSize = .zero,
                   zIndex: Double = 0) -> PatchNode {

    let oval = CGRect.defaultOval

    let inputs = toInputs(
        id: id,
        values:
            ("Position", [.position(oval.origin)]),
        ("Size", [.size(oval.size.toLayerSize)])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values:
            ("Shape", [.shape(CustomShape(.oval(oval)))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .ovalShape,
        inputs: inputs,
        outputs: outputs)
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
