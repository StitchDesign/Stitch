//
//  DevicedeviceTimeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct DeviceTimePatchNode: PatchNodeDefinition {
    static let patch = Patch.deviceTime
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [],
            outputs: [
                .init(
                    label: "Seconds",
                    type: .number
                ),
                .init(
                    label: "Milliseconds",
                    type: .number
                )
            ]
        )
    }
}

// Doesn't actually need anything
func deviceTimeEval(node: PatchNode) -> EvalResult {

    // All the magic is done by Swift's `Date()` type.
    let currentDeviceTime = Date()
    let seconds = currentDeviceTime.timeIntervalSince1970
    let roundedSeconds = seconds.rounded(.towardZero)
    let milliseconds = seconds - roundedSeconds

    // DeviceTime node has no inputs, and so can never have a loop.
    let newOutputs: PortValuesList = [
        [.number(roundedSeconds)],
        [.number(milliseconds)]
    ]

    return .init(outputsValues: newOutputs)
}
