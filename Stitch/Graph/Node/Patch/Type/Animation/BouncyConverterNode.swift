//
//  BouncyConverterNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/5/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct BouncyConverterNode: PatchNodeDefinition {
    static let patch = Patch.bouncyConverter
    
    static let defaultUserVisibleType: UserVisibleType? = .number
    
    static func rowDefinitions(for type: StitchSchemaKit.UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(defaultValues: [.number(sampleBounciness)],
                      label: "Bounciness"),
                .init(defaultValues: [.number(sampleSpeed)],
                      label: "Speed")
            ],
            outputs: [
                .init(label: "Friction",
                      type:  .number),
                .init(label: "Tension",
                      type:  .number)
            ]
        )
    }
}

func bouncyConverterEval(inputs: PortValuesList,
                         outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in

        let bounciness = values.first?.getNumber ?? 0
        let speed = values[1].getNumber ?? 0

        let (friction,
             tension) = convertBouncinessAndSpeedToFrictionAndTension(
                bounciness: bounciness,
                speed: speed)

        return (
            .number(friction),
            .number(tension)
        )
    }

    return resultsMaker2(inputs)(op)
}
