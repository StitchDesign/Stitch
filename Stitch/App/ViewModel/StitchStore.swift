//
//  StitchStore.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/24/22.
//

import AudioKit
import SwiftUI
import StitchSchemaKit

typealias StoreDelegate = StitchStore

@Observable
final class StitchStore: Sendable {
    
    @MainActor var llmRecordingModeEnabled: Bool = false
    
    @MainActor var allProjectUrls = [ProjectLoader]()
    let documentLoader = DocumentLoader()
    let clipboardEncoder = ClipboardEncoder()
    let clipboardDelegate = ClipboardEncoderDelegate()
    
    @MainActor var alertState: ProjectAlertState
    
    @MainActor
    var systems: [StitchSystemType: StitchSystemViewModel] = [:]
    
    // Components are unqiue to a user, not to a project,
    // and loaded when app loads.
    //    var defaultComponents = ComponentsDict()
    
    // Navigation path for viewing documents
    @MainActor var navPath: [ProjectLoader] = []
    
    @MainActor var isShowingDrawer = false
    
    // TODO: should be properly persisted
    @MainActor var edgeStyle: EdgeStyle = .defaultEdgeStyle
    @MainActor var appTheme: StitchTheme = .defaultTheme
    
    // Tracks ID of project which has a title that's currently getting modified
    @MainActor var projectIdForTitleEdit: ProjectId?
    
    let environment: StitchEnvironment
    
    @MainActor
    init() {
        self.environment = StitchEnvironment()
        self.alertState = .init()
        
        // Remove cached data from previous session
        try? FileManager.default.removeItem(at: StitchFileManager.tempDir)
        
        // Sets up action dispatching
        GlobalDispatch.shared.delegate = self
        
        self.environment.dirObserver.delegate = self
        self.environment.store = self
        self.clipboardEncoder.delegate = self.clipboardDelegate
        self.clipboardDelegate.store = self
    }
}

extension StitchStore {
    // Gets the Redux-style state for legacy purposes
    @MainActor
    func getState() -> AppState {
        AppState(
            edgeStyle: self.edgeStyle,
            appTheme: self.appTheme,
            isShowingDrawer: self.isShowingDrawer,
            projectIdForTitleEdit: self.projectIdForTitleEdit
        )
    }
}

final class ClipboardEncoderDelegate: DocumentEncodableDelegate {
    var lastEncodedDocument: StitchClipboardContent
    @MainActor weak var store: StitchStore?
    
    init() {
        self.lastEncodedDocument = .init()
    }
    
    func createSchema(from graph: GraphState?) -> StitchClipboardContent {
        fatalError()
    }
    
    func willEncodeProject(schema: StitchClipboardContent) {}
    
    func updateAsync(from schema: StitchClipboardContent) async { }
    
    var storeDelegate: StitchStore? {
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
    @MainActor
    func reswiftDispatch(_ legacyAction: Action) {
        _handleAction(store: self, action: legacyAction)
    }
}

extension StitchStore {
    @MainActor
    var isCurrentProjectSelected: Bool {
        self.currentProjectId.isDefined
    }

    @MainActor
    var currentProjectId: ProjectId? {
        currentDocument?.projectId
    }

    @MainActor
    var currentDocument: StitchDocumentViewModel? {
        self.navPath.first?.documentViewModel
    }
    
    var undoManager: StitchUndoManager {
        self.environment.undoManager
    }
}
