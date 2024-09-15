//
//  StitchStore.swift
//  prototype
//
//  Created by Elliot Boschwitz on 5/24/22.
//

import AudioKit
import SwiftUI
import StitchSchemaKit

@Observable
final class StitchStore: Sendable, StoreDelegate {
        
    var llmRecordingModeEnabled: Bool = false
    
    var allProjectUrls = [ProjectLoader]()
    let documentLoader = DocumentLoader()

    // Components are unqiue to a user, not to a project,
    // and loaded when app loads.
    //    var defaultComponents = ComponentsDict()

    // Navigation path for viewing documents
    var navPath: [StitchDocumentViewModel] = []

    var isShowingDrawer = false

    // TODO: should be properly persisted
    var edgeStyle: EdgeStyle = .defaultEdgeStyle
    var appTheme: StitchTheme = .defaultTheme
    @MainActor var alertState = ProjectAlertState()

    // Tracks ID of project which has a title that's currently getting modified
    var projectIdForTitleEdit: ProjectId?

    let environment = StitchEnvironment()

    @MainActor
    init() {
        // Sets up action dispatching
        GlobalDispatch.shared.delegate = self

        self.environment.dirObserver.delegate = self
        self.environment.store = self
    }

    // Gets the Redux-style state for legacy purposes
    @MainActor
    func getState() -> AppState {
        AppState(
            edgeStyle: self.edgeStyle,
            appTheme: self.appTheme,
            isShowingDrawer: self.isShowingDrawer,
            projectIdForTitleEdit: self.projectIdForTitleEdit,
            alertState: self.alertState
        )
    }
}

extension StitchStore {
    
    @MainActor
    func displayError(error: StitchFileError) {
        self.alertState.stitchFileError = error
    }
}

extension StitchStore: GlobalDispatchDelegate {
    func reswiftDispatch(_ legacyAction: Action) {
        _handleAction(store: self, action: legacyAction)
    }
}

extension StitchStore {
    var isCurrentProjectSelected: Bool {
        self.currentProjectId.isDefined
    }

    var currentProjectId: ProjectId? {
        currentGraph?.projectId
    }

    var currentDocument: StitchDocumentViewModel? {
        self.navPath.first
    }
    
    var currentGraph: GraphState? {
        self.currentDocument?.graph
    }
}
