//
//  StitchEnvironment.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/3/23.
//

import Foundation
import StitchSchemaKit

@Observable
final class StitchEnvironment {
    let fileManager: StitchFileManager
    let logListener: LogListener
    let undoManager: StitchUndoManager
    let dirObserver: DirectoryObserver

    // weak reference to avoid retain cycle
    weak var store: StitchStore?

    init(fileManager: StitchFileManager = StitchFileManager()) {

        self.logListener = LogListener()
        self.undoManager = StitchUndoManager()

        let fileManager = fileManager

        // Track changes to projects in cloud. Keeps `ProjectsView` up to date
        // while visible.
        let docsUrl = StitchFileManager.documentsURL.url
        self.dirObserver = DirectoryObserver(URL: docsUrl)
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
