//
//  StitchEnvironment.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/3/23.
//

import Foundation
import StitchSchemaKit

@Observable
final class StitchEnvironment: Sendable {
    let fileManager: StitchFileManager
    let undoManager: StitchUndoManager
    let dirObserver: DirectoryObserver

    // weak reference to avoid retain cycle
    @MainActor weak var store: StitchStore?

    @MainActor
    init(fileManager: StitchFileManager = StitchFileManager()) {

        self.undoManager = StitchUndoManager()

        let fileManager = fileManager

        // Track changes to projects in cloud. Keeps `ProjectsView` up to date
        // while visible.
        let docsUrl = StitchFileManager.documentsURL
        self.dirObserver = DirectoryObserver(url: docsUrl)
        self.fileManager = fileManager

        self.store = store
    }
}

extension GraphState {
    @MainActor
    var graphStepState: GraphStepState {
        self.graphStepManager.graphStepState
    }
}
