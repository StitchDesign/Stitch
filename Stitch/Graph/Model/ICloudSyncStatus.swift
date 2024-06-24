//
//  ICloudSyncStatus.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/16/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let ICLOUD_SYNCING_IMAGE_NAME = "arrow.clockwise.icloud"
let ICLOUD_SYNCED_IMAGE_NAME = "checkmark.icloud"
let ICLOUD_OFFLINE = "icloud.slash"
let ICLOUD_SYNC_ERRR = "exclamationmark.icloud"

enum iCloudSyncStatus: Codable, Equatable {
    case syncing, synced, offline, error

    var sfSymbol: String {
        switch self {
        case .syncing:
            return ICLOUD_SYNCING_IMAGE_NAME
        case .synced:
            return ICLOUD_SYNCED_IMAGE_NAME
        case .offline:
            return ICLOUD_OFFLINE
        case .error:
            return ICLOUD_SYNC_ERRR
        }
    }

    mutating func startSyncAttempt() {
        self = .syncing
    }
}
