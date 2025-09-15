//
//  TanNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Numerics


struct ArcTan2PatchNode: PatchNodeDefinition {
    static let patch = Patch.arcTan2

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Y"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "X"
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

@MainActor
func arcTan2Eval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        if let y = values.first?.getNumber,
           let x = values[1].getNumber {
            return .number(atan2(y, x)
                            .radiansToDegrees
                            .rounded(toPlaces: 5))
        }

        fatalErrorIfDebug()
        return .number(.zero)
    }

    return resultsMaker(inputs)(op)
}
