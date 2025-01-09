//
//  ProjectLoader.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/25/24.
//

import Foundation
import SwiftUI

// MARK: hashable for navpath
extension ProjectLoader: Hashable {
    static func == (lhs: ProjectLoader, rhs: ProjectLoader) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

/// Passed into view to property sort URLs by modified date and forces a new render cycle when the date changes.
@Observable
final class ProjectLoader: Sendable, Identifiable {
    let id: Int
    let url: URL
    
    @MainActor var modifiedDate: Date
    @MainActor var encoder: DocumentEncoder?
    
    @MainActor var loadingDocument: DocumentLoadingStatus = .initialized {
        didSet {
            if let loadedDocument = self.loadingDocument.document {
                self.lastEncodedDocument = loadedDocument
            }
        }
    }
    
    @MainActor var thumbnail: UIImage?

    // Needs to be separate from loadingDocument so it can always be accessed even when loading
    @MainActor var lastEncodedDocument: StitchDocument?
    
    // assigned if project is opened
    @MainActor var documentViewModel: StitchDocumentViewModel?

    /// Initialzes object with some URL, not yet loading document until loaded in lazy view.
    @MainActor init(url: URL) {
        // log("ProjectLoader: init: url: \(url)")
        self.url = url
        self.id = url.hashValue

        // Sort URLS by project modification date, excluding metadata changes
        self.modifiedDate = url
            .getLastModifiedDate(fileManager: FileManager.default)
    }
}

extension ProjectLoader {
    @MainActor
    func resetData() {
        self.loadingDocument = .loading
        self.thumbnail = nil
    }
}
