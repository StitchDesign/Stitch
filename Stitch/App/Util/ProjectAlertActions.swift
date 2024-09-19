//
//  ProjectAlertActions.swift
//  prototype
//
//  Created by Elliot Boschwitz on 12/1/21.
//

import SwiftUI
import StitchSchemaKit

// Set state value to false if alert is dismissed
struct ProjectDeletedAlertCompleted: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.isCurrentProjectDeleted = false
        return .stateOnly(state)
    }
}

// Careful: if two different views both dispatch a Toggle event at the same time, then the state change will be unintentionally canceled out.
struct ToggleFullScreenPreviewSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showFullScreenPreviewSheet.toggle()
        return .stateOnly(state)
    }
}

struct ShowFullScreenPreviewSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showFullScreenPreviewSheet = true
        return .stateOnly(state)
    }
}

struct CloseFullScreenPreviewSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showFullScreenPreviewSheet = false
        return .stateOnly(state)
    }
}

struct ShowProjectSettingsSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showProjectSettings = true
        return .stateOnly(state)
    }
}

struct ShowAppSettingsSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showAppSettings = true
        return .stateOnly(state)
    }
}

extension StitchStore {
    @MainActor func hideProjectSettingsSheet() {
        var alertState = self.alertState
        alertState.showProjectSettings = false
        self.alertState = alertState
    }
    
    @MainActor func hideAppSettingsSheet() {
        var alertState = self.alertState
        alertState.showAppSettings = false
        self.alertState = alertState
    }
}

struct HideAppSettingsSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showAppSettings = false
        return .stateOnly(state)
    }
}

struct ShowFileImportModal: ProjectAlertEvent {
    // Used if we're importing to an already existing node
    var nodeImportPayload: NodeMediaImportPayload?

    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        log("ShowFileImportModal called")
        var state = state
        state.fileImportModalState = .importing(nodeImportPayload)
        return .stateOnly(state)
    }
}

struct HideFileImportModal: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        log("HideFileImportModal called")
        var state = state
        state.fileImportModalState = .notImporting
        return .stateOnly(state)
    }
}

struct ReceivedStitchFileError: ProjectAlertEvent {
    let error: StitchFileError

    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        log("ReceivedStitchFileError: \(error)")
        var state = state
        state.stitchFileError = error

        // Hide quickstart menu
        state.showSampleAppsSheet = false

        return .stateOnly(state)
    }
}

struct HideStitchFileErrorAlert: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.stitchFileError = nil
        return .stateOnly(state)
    }
}

struct ToggleSampleProjectSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showSampleAppsSheet.toggle()
        return .stateOnly(state)
    }
}

struct HideSampleProjectSheet: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showSampleAppsSheet = false
        return .stateOnly(state)
    }
}

struct ShowDeleteAllProjectsConfirmation: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showDeleteAllProjectsConfirmation = true
        return .stateOnly(state)
    }
}

struct HideDeleteAllProjectsConfirmation: ProjectAlertEvent {
    func handle(state: ProjectAlertState) -> ProjectAlertResponse {
        var state = state
        state.showDeleteAllProjectsConfirmation = false
        return .stateOnly(state)
    }
}
