//
//  UnionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func unionNode(id: NodeId,
               position: CGSize = .zero,
               zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.shape(nil)]),
        (nil, [.shape(nil)])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values:
            (nil, [.shape(nil)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .union,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func unionEval(inputs: PortValuesList,
               outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        // there's always at least two inputs,
        // but there could be many more.

        if var shapeList = values.first?.getShape?.shapes {
            for shape in values.tail.compactMap(\.getShape?.shapes) {
                // each .shape is technically a list of other shapes
                shapeList.append(contentsOf: shape)
            }
            return .shape(.init(shapes: shapeList))
        }
        return .shape(nil)
    }

    return resultsMaker(inputs)(op)
}
