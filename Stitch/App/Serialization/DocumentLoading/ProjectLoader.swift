//
//  ProjectLoader.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/25/24.
//

import Foundation
import SwiftUI

/// Passed into view to property sort URLs by modified date and forces a new render cycle when the date changes.
@Observable
final class ProjectLoader: Sendable, Identifiable {
    let id: Int
    @MainActor var encoder: DocumentEncoder?
    
    @MainActor var modifiedDate: Date
    @MainActor var url: URL
    @MainActor var loadingDocument: DocumentLoadingStatus = .initialized
    @MainActor var thumbnail: UIImage?

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
