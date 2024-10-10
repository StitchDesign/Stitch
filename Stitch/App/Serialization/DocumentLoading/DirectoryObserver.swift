//
//  DirectoryObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/18/21.
//

import Foundation
import StitchSchemaKit
import DirectoryWatcher

protocol DirectoryObserverDelegate: AnyObject {
    func directoryUpdated() async
}

/// Class for notifying changes in a directory. Used for tracking updates to the `ProjectsView`.
/// Source: https://stackoverflow.com/a/43478015
final class DirectoryObserver {
    private let source: DirectoryWatcher?
    weak var delegate: DirectoryObserverDelegate?


    init(url: URL) {
        self.source = DirectoryWatcher.watch(url)

        self.source?.onNewFiles = { _ in
            Task { [weak self] in
                await self?.delegate?.directoryUpdated()
            }
        }
        
        self.source?.onDeletedFiles = { _ in
            Task { [weak self] in
                await self?.delegate?.directoryUpdated()
            }
        }
    }
}
