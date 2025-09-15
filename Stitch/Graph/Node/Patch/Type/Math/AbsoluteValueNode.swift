//
//  AbsoluteValueNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/25/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit


struct AbsoluteValuePatchNode: PatchNodeDefinition {
    static let patch = Patch.absoluteValue

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
                    label: ""
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
func absoluteValueEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    // log("absoluteValueEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        // log("absoluteValueEval: values: \(values)")
        let n = values[0].getNumber!

        // ie if n == n2, then just use n
        let absoluteValue: Double = abs(n)

        return .number(absoluteValue)
    }

    return resultsMaker(inputs)(op)
}
