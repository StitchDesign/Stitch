//
//  DirectoryObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/18/21.
//

import Foundation
import StitchSchemaKit
@preconcurrency import DirectoryWatcher

protocol DirectoryObserverDelegate: AnyObject, Sendable {
    func directoryUpdated()
}

/// Class for notifying changes in a directory. Used for tracking updates to the `ProjectsView`.
/// Source: https://stackoverflow.com/a/43478015
final class DirectoryObserver: Sendable {
    private let source: DirectoryWatcher?
    @MainActor weak var delegate: DirectoryObserverDelegate?

    init(url: URL) {
        self.source = DirectoryWatcher.watch(url)

        self.source?.onNewFiles = { _ in
            self.delegate?.directoryUpdated()
        }
        
        self.source?.onDeletedFiles = { _ in
            self.delegate?.directoryUpdated()
        }
    }
}
