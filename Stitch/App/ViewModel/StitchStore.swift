//
//  StitchStore.swift
//  Stitch
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
    let clipboardEncoder = ClipboardEncoder()
    let clipboardDelegate = ClipboardEncoderDelegate()
    
    var systems: [StitchSystemType: StitchSystemViewModel] = [:]

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
        self.clipboardEncoder.delegate = self.clipboardDelegate
        self.clipboardDelegate.store = self
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

final class ClipboardEncoderDelegate: DocumentEncodableDelegate {
    weak var store: StitchStore?
    
    init() { }
    
    func createSchema(from graph: GraphState?) -> StitchClipboardContent {
        fatalError()
    }
    
    func willEncodeProject(schema: StitchClipboardContent) {}
    
    func update(from schema: StitchClipboardContent) async { }
    
    var storeDelegate: (any StoreDelegate)? {
        self.store
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
    
    var undoManager: StitchUndoManager {
        self.environment.undoManager
    }
}
