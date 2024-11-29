//
//  LocationManager.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/16/22.
//

import Foundation
import StitchSchemaKit
@preconcurrency import CoreLocation

final class LocationManager: NSObject, Sendable {

    static let locationManager: CLLocationManager = CLLocationManager()
    
    //    // nil when:
    //    // 1. manager first created, or
    //    // 2. when we've never received a location-update
    //    var locationAndAddress: LocationAddress?
    //
    //    func locationUpdatedCallback(newLocation: CLLocation,
    //                                 maybeString: String?) {
    //        self.locationAndAddress = LocationAddress(
    //            location: newLocation.coordinate,
    //            address: maybeString ?? LOCATION_ADDRESS_UNKNOWN)
    //        self.safeDispatch(LocationUpdateReceived())
    //    }

    // TODO: should check existing permissions status and not request permission again if we're already authorized
    // so far, seems to be okay to request again

    @MainActor var locationAndAddress: LocationAddress?

    override init() {
        super.init()
        Self.locationManager.delegate = self
        Self.setupLocationManager()
    }

    // Called when:
    // 1. we open a graph that has at least one Location node
    // 2. we create a
    static func setupLocationManager() {
        log("locationManager: setupLocationManager")
        let locationManager = Self.locationManager
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        // Required, else `requestLocation` takes 5+ seconds
        locationManager.startUpdatingLocation()
    }
}

typealias LocationUpdatedCallback = (CLLocation, String?) -> Void

extension LocationManager: CLLocationManagerDelegate, MiddlewareService {
    @MainActor
    func locationUpdatedCallback(_ newLocation: CLLocation,
                                 _ maybeString: String?) {
        self.locationAndAddress = LocationAddress(
            location: newLocation.coordinate,
            address: maybeString ?? LOCATION_ADDRESS_UNKNOWN)
        dispatch(LocationUpdateReceived())
    }

    // TODO: handle this properly
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {

        log("locationManager: didChangeAuthorization: \(status)")

        switch status {

        case .authorizedAlways, .authorizedWhenInUse:
            // If we received a new, updated and successful auth status,
            // start requesting updates again.
            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
            manager.startUpdatingLocation()

        case .denied, .restricted:
            // TODO: update alertState
            manager.stopUpdatingLocation()

        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            log("locationManager: unknown authorization status: \(status)")
        }
    }

    // When we receive the location,
    // we update the locationManager's state
    // and dispatch an action to update location nodes.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {

        log("locationManager: didUpdateLocations: \(locations)")

        if let newLocation = locations.first {

            CLGeocoder().reverseGeocodeLocation(newLocation, completionHandler: { (placemarks, error) in
                Task { @MainActor [weak self] in
                    if let error = error {
                        print("Error when attempting reverse geocode: \(error.localizedDescription)")
                        self?.locationUpdatedCallback(newLocation, nil)
                    } else if let placemark = placemarks?.first,
                              let addressString = placemark.addressString {
                        log("Had placemark: addressString: \(addressString)")
                        self?.locationUpdatedCallback(newLocation, addressString)
                    } else {
                        log("Did not have placemark")
                        self?.locationUpdatedCallback(newLocation, nil)
                    }
                }
            })
        }
    }

    // TODO: update alertState
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Swift.Error) {
        log("locationManager: didFailWithError: error: \(error)")
    }
}

import Contacts

extension CLPlacemark {
    var addressString: String? {
        self.postalAddress.map {
            CNPostalAddressFormatter().string(from: $0)
        }

    }
}
