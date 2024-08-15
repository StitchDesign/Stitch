//
//  TransformPackPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct TransformPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.transformPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let inputTransform = DEFAULT_TRANSFORM_MATRIX
        return NodeRowDefinitions(inputs: [
            .init(defaultValues: [.number(Double(inputTransform.position.x))],
                  label: "Position X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.position.y))],
                  label: "Position Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.position.z))],
                  label: "Position Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.scale.x))],
                  label: "Scale X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.scale.y))],
                  label: "Scale Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.scale.z))],
                  label: "Scale Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotation.imag.x))],
                  label: "Rotation X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotation.imag.y))],
                  label: "Rotation Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotation.imag.z))],
                  label: "Rotation Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotation.real))],
                  label: "Rotation Real",
                  isTypeStatic: true)
        ],
        outputs: [
            .init(type: .transform)
        ])

    }
}

func transformPackEval(inputs: PortValuesList,
                             outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(transformPackOp)
}
