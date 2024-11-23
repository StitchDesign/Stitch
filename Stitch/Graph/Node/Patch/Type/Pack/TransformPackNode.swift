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
        let inputTransform = DEFAULT_STITCH_TRANSFORM
        return NodeRowDefinitions(inputs: [
            .init(defaultValues: [.number(Double(inputTransform.positionX))],
                  label: "Position X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.positionY))],
                  label: "Position Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.positionZ))],
                  label: "Position Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.scaleX))],
                  label: "Scale X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.scaleY))],
                  label: "Scale Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.scaleZ))],
                  label: "Scale Z",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotationX))],
                  label: "Rotation X",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotationY))],
                  label: "Rotation Y",
                  isTypeStatic: true),
            .init(defaultValues: [.number(Double(inputTransform.rotationZ))],
                  label: "Rotation Z",
                  isTypeStatic: true)
        ],
        outputs: [
            .init(type: .transform)
        ])

    }
}

@MainActor
func transformPackEval(inputs: PortValuesList,
                             outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(transformPackOp)
}
