//
//  wirelessReceiverNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct WirelessReceiverPatchNode: PatchNodeDefinition {
    static let patch = Patch.wirelessReceiver

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
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

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}
