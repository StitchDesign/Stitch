//
//  UnionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct UnionPatchNode: PatchNodeDefinition {
    static let patch = Patch.union
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.shape(nil)],
                    label: ""
                ),
                .init(
                    defaultValues: [.shape(nil)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .shape
                )
            ]
        )
    }
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
