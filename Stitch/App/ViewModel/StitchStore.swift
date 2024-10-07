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
    
    var systems: [UUID: StitchSystemViewModel] = [:]

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
    
    var undoManager: StitchUndoManager {
        self.environment.undoManager
    }
}

// TODO: move
final class StitchSystemViewModel {
    var data: StitchSystem
    
    var componentEncoders: [UUID: ComponentEncoder] = [:]
    
    weak var storeDelegate: StoreDelegate?

    init(data: StitchSystem,
         storeDelegate: StoreDelegate?) {
        self.data = data
        self.storeDelegate = storeDelegate
    }
}

extension StitchSystemViewModel: DocumentEncodableDelegate {
    @MainActor func createSchema(from graph: GraphState) -> StitchSystem {
        self.data
    }
    
    @MainActor func willEncodeProject(schema: StitchSystem) { }

    func updateOnUndo(schema: StitchSystem) { }
}

final actor SystemsEncoder: DocumentEncodable {
    var id: UUID
    let rootUrl: URL
    
    @MainActor var lastEncodedDocument: StitchSystem
    @MainActor weak var delegate: StitchSystemViewModel?
    
    init(system: StitchSystem,
         delegate: StitchSystemViewModel) {
        self.id = system.id
        self.lastEncodedDocument = system
        self.rootUrl = system.rootUrl
        self.delegate = delegate
    }
}

public enum StitchSystem_V25: StitchSchemaVersionable {

    // MARK: - ensure versions are correct
    public static let version = StitchSchemaVersion._V25
    public typealias PreviousInstance = Self.StitchSystem
    // MARK: - end

    public struct StitchSystem: StitchVersionedCodable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        
        public init(id: UUID,
                    name: String) {
            self.id = id
            self.name = name
        }
    }
}

extension StitchSystem_V25.StitchSystem {
    public init(previousInstance: StitchSystem_V25.PreviousInstance) {
        // TODO: fix after version 25 (wasn't encoded ever in version 24)
        fatalError()
    }
}


import UniformTypeIdentifiers

extension StitchSystem: StitchDocumentEncodable, StitchDocumentMigratable {
    init() {
        self.init(id: .init(),
                  name: "New System")
    }
    
    typealias VersionType = StitchSystemVersion
    
    static let unzippedFileType: UTType = .stitchSystemUnzipped
    static let zippedFileType: UTType = .stitchSystemZipped
}
