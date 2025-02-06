//
//  ProjectAlertActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/1/21.
//

import SwiftUI
import StitchSchemaKit

// Set state value to false if alert is dismissed
struct ProjectDeletedAlertCompleted: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.isCurrentProjectDeleted = false
    }
}

// Careful: if two different views both dispatch a Toggle event at the same time, then the state change will be unintentionally canceled out.
struct ToggleFullScreenPreviewSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showFullScreenPreviewSheet.toggle()
    }
}

struct ShowFullScreenPreviewSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showFullScreenPreviewSheet = true
    }
}

struct CloseFullScreenPreviewSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showFullScreenPreviewSheet = false
    }
}

struct ShowProjectSettingsSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showProjectSettings = true
    }
}

struct ShowAppSettingsSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showAppSettings = true
    }
}

extension StitchStore {
    @MainActor func hideProjectSettingsSheet() {
        self.alertState.showProjectSettings = false
    }
    
    @MainActor func hideAppSettingsSheet() {
        self.alertState.showAppSettings = false
    }
}

struct HideAppSettingsSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showAppSettings = false
    }
}

struct ShowFileImportModal: ProjectAlertEvent {
    // Used if we're importing to an already existing node
    var nodeImportPayload: NodeMediaImportPayload?

    func handle(state: ProjectAlertState) {
        log("ShowFileImportModal called")
        state.fileImportModalState = .importing(nodeImportPayload)
    }
}

struct HideFileImportModal: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        log("HideFileImportModal called")
        state.fileImportModalState = .notImporting
    }
}

struct ReceivedStitchFileError: ProjectAlertEvent {
    let error: StitchFileError

    func handle(state: ProjectAlertState) {
        log("ReceivedStitchFileError: \(error)")
        state.stitchFileError = error

        // Hide quickstart menu
        state.showSampleAppsSheet = false
    }
}

struct HideStitchFileErrorAlert: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.stitchFileError = nil
    }
}

struct ToggleSampleProjectSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showSampleAppsSheet.toggle()
    }
}

struct HideSampleProjectSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showSampleAppsSheet = false
    }
}

struct ShowDeleteAllProjectsConfirmation: ProjectAlertEvent {
    func handle(state: ProjectAlertState) {
        state.showDeleteAllProjectsConfirmation = true
    }
}
