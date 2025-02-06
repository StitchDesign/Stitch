//
//  ProjectAlertState.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/1/21.
//

import SwiftUI
import StitchSchemaKit

@Observable
final class ProjectAlertState: Sendable {
    // Shows alert if currently opened project is deleted elsewhere
    @MainActor var isCurrentProjectDeleted = false

    // Toggles action sheet for full screen preview on iOS
    @MainActor var showFullScreenPreviewSheet = false

    // Modal for app-wide settings
    @MainActor var showAppSettings = false

    // Modal for project-specific settings
    @MainActor var showProjectSettings = false
    
    @MainActor var showCameraPermissionsAlert = false

    // Modal for file import
    @MainActor var fileImportModalState = FileImportState.notImporting

    // Error to display to user if any stage of serialization fails
    @MainActor var stitchFileError: StitchFileError?

    // Sheet for list of quick-start sample projects
    @MainActor var showSampleAppsSheet = false

    // If a project was recently deleted, store the undo event here
    @MainActor var deletedProjectId: ProjectId?

    // Alert state to confirm deleting ALL projects
    @MainActor var showDeleteAllProjectsConfirmation = false
    
    @MainActor init() { }
}

/// A boolean wrapper which reflects the visibile state of the import file sheet. Provides an optional "destination" input
/// coordiante if import will overwrite an existing node's input.
enum FileImportState: Codable, Equatable {
    case importing(NodeMediaImportPayload? = nil)
    case notImporting
}

/// Payload used for import scenarios where imported media is added to an existing node
struct NodeMediaImportPayload: Codable, Equatable {
    let destinationInputs: [InputCoordinate] // more than 1 if edited from layer inspector via multiselect
    let mediaFormat: SupportedMediaFormat
}

extension FileImportState {
    var nodeImportPayload: NodeMediaImportPayload? {
        switch self {
        case .importing(let payload):
            return payload
        case .notImporting:
            return nil
        }
    }

    var isImporting: Bool {
        switch self {
        case .importing:
            return true
        case .notImporting:
            return false
        }
    }
}
