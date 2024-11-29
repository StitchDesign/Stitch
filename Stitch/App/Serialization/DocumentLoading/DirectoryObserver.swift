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
    @MainActor func directoryUpdated()
}

/// Class for notifying changes in a directory. Used for tracking updates to the `ProjectsView`.
/// Source: https://stackoverflow.com/a/43478015
final actor DirectoryObserver {
    private let source: DirectoryWatcher?
    @MainActor weak var delegate: DirectoryObserverDelegate?

    init(url: URL) {
        guard let watcher = DirectoryWatcher.watch(url) else {
            fatalErrorIfDebug()
            self.source = nil
            return
        }
        
        self.source = watcher

        watcher.onNewFiles = { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.directoryUpdated()
            }
        }
        
        watcher.onDeletedFiles = { _ in
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.directoryUpdated()
            }
        }
    }
}
