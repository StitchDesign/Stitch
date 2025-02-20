//
//  LocationData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/16/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreLocation

let CUPERTINO_COORDINATE: CLLocationCoordinate2D = .init(
    latitude: 37.3230,
    longitude: 122.0322)

let CUPERTINO_ADDRESS: String = "Cupertino, CA, USA"

let LOCATION_ADDRESS_UNKNOWN = "unknown"

extension CLLocationCoordinate2D: Equatable {}

public func == (lhs: CLLocationCoordinate2D,
                rhs: CLLocationCoordinate2D) -> Bool {
    lhs.latitude == rhs.latitude
        && lhs.longitude == rhs.longitude
}

struct LocationAddress: Equatable {

    // Cupertino: 37.3230° N, 122.0322° W
    var location: CLLocationCoordinate2D = CUPERTINO_COORDINATE

    var address: String = CUPERTINO_ADDRESS

    static let defaultLocationAddress = Self.init(
        location: CUPERTINO_COORDINATE,
        address: CUPERTINO_ADDRESS)
}

struct LocationUpdateReceived: ProjectEnvironmentEvent {

    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {
        log("LocationUpdateReceived called")

        var effects = SideEffects()

        let locationNodes = graphState.visibleNodesViewModel.nodes.locationNodes.map { $0.id }.toSet
        graphState.scheduleForNextGraphStep(locationNodes)

        return .noChange
    }
}
