//
//  CoSinNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Numerics


struct CosinePatchNode: PatchNodeDefinition {
    static let patch = Patch.cosine

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Angle"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }
}

// Swift `cos(n)` expects RADIANS;
// but Origami `angle` is in DEGREES
@MainActor
func cosineEval(inputs: PortValuesList,
                outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        if let angle = values.first?.getNumber {
            return .number(
                cos(angle.degreesToRadians)
                    .rounded(toPlaces: 5))
        }

        #if DEBUG
        fatalError()
        #endif
        return .number(.zero)
    }

    return resultsMaker(inputs)(op)
}
