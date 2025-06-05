//
//  ProjectsUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/14/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit
import CloudKit


@MainActor
let isPhoneDevice = UIDevice.current.userInterfaceIdiom == .phone


@MainActor
func getCloudKitUsername() async throws -> String? {
    do {
        let recordID = try await CKContainer.default().userRecordID()
        let userIdString = recordID.recordName
        print("✅ Fetched user record ID (async):", userIdString)
        return userIdString
    } catch {
        print("❌ Error fetching user record ID (async):", error)
        return nil // e.g. offline
    }
}

// TODO: should live on app-wide state, retrieved at app start and be non-optional
@MainActor
func getDeviceUUID() -> String? {
    guard let deviceUUID = UIDevice.current.identifierForVendor?.uuidString else {
        fatalErrorIfDebug("Unable to retrieve device UUID")
        return nil
    }
    return deviceUUID
}

// TODO: should live on app-wide state, retrieved at app start and be non-optional
@MainActor
func getReleaseVersion() -> String? {
    guard let releaseVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
        fatalErrorIfDebug("Could not retrieve release version")
        return nil
    }
    return releaseVersion
}
