//
//  LocationNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/16/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// No node type or user-node types
// No inputs (i.e. inputs are disabled)
struct LocationNode: PatchNodeDefinition {
    static let patch = Patch.location

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Override"
                )
            ],
            outputs: [
                .init(
                    label: "Latitude",
                    type: .number
                ),
                .init(
                    label: "Longitude",
                    type: .number
                ),
                .init(
                    label: "Name",
                    type: .string
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        SingletonMediaNodeCoordinator()
    }
}

func createLocationManager(state: StitchDocumentViewModel,
                           nodeId: NodeId) async -> StitchSingletonMediaObject {
    .locationManager(LocationManager())
}

@MainActor
func locationEval(node: PatchNode,
                  document: StitchDocumentViewModel) -> ImpureEvalResult {
    asyncSingletonMediaEval(node: node,
                            document: document,
                            mediaCreation: createLocationManager,
                            mediaManagerKeyPath: \.locationManager) { _, locationManager, _ in

        let location = locationManager.locationManager?.locationAndAddress ?? .defaultLocationAddress
        let lat = location.location.latitude
        let long = location.location.longitude
        let address = location.address

        return [.number(lat),
                .number(long),
                .string(.init(address))]
    }
                            .toImpureEvalResult()
}
