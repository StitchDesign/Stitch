//
//  DirectoryObserver.swift
//  prototype
//
//  Created by Elliot Boschwitz on 10/18/21.
//

import Foundation
import StitchSchemaKit

protocol DirectoryObserverDelegate: AnyObject {
    func directoryUpdated()
}

/// Class for notifying changes in a directory. Used for tracking updates to the `ProjectsView`.
/// Source: https://stackoverflow.com/a/43478015
final class DirectoryObserver {
    private let fileDescriptor: CInt
    private let source: DispatchSourceProtocol

    weak var delegate: DirectoryObserverDelegate?

    deinit {
        self.source.cancel()
        close(fileDescriptor)
    }

    init(URL: URL) {
        self.fileDescriptor = open(URL.path, O_EVTONLY)
        self.source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: self.fileDescriptor,
            eventMask: .all,
            queue: DispatchQueue.global())

        self.source.setEventHandler { [weak self] in
            self?.delegate?.directoryUpdated()
        }
        self.source.resume()
    }
}
