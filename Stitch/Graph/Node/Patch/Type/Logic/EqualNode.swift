//
//  EqualNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct EqualsPatchNode: PatchNodeDefinition {
    static let patch = Patch.equals
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Threshold"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .bool
                )
            ]
        )
    }
}

@MainActor
func equalsEval(inputs: PortValuesList,
                outputs: PortValuesList) -> PortValuesList {

    resultsMaker(inputs)({ (values: PortValues) -> PortValue in
        if let first = values[0].getNumber,
           let second = values[1].getNumber,
           let threshold = values[2].getNumber {

            return .bool(first.isEqualWithinThreshold(
                            to: second,
                            threshold: threshold))
        }
        log("equalsEval: error")
        return .bool(false)
    })
}

extension Double {
    func isEqualWithinThreshold(to: Double,
                                threshold: Double) -> Bool {

        equalWithinThreshold(n: self,
                             n2: to,
                             threshold: threshold)
    }
}

func equalWithinThreshold(n: Double,
                          n2: Double,
                          threshold: Double = IS_SAME_DIFFERENCE_ALLOWANCE_LEGACY) -> Bool {
    abs(n - n2) <= threshold
}
