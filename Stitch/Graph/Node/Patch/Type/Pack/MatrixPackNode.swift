//
//  MatrixPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct MatrixPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.matrixTransformPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let inputMatrix = DEFAULT_TRANSFORM_MATRIX_MODEL
        return NodeRowDefinitions(inputs: [
            .init(defaultValues: [.number(Double(inputMatrix.position.x))],
                  label: "Position X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.position.y))],
                  label: "Position Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.position.z))],
                  label: "Position Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.scale.x))],
                  label: "Scale X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.scale.y))],
                  label: "Scale Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.scale.z))],
                  label: "Scale Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.rotation.imag.x))],
                  label: "Rotation X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.rotation.imag.y))],
                  label: "Rotation Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.rotation.imag.z))],
                  label: "Rotation Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputMatrix.rotation.real))],
                  label: "Rotation Real",
                  isTypeStatic: true)
        ],
        outputs: [
            .init(type: .matrixTransform)
        ])

    }
}

func matrixTransformPackEval(inputs: PortValuesList,
                             outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(matrixPackOp)
}
