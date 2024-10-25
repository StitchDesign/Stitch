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
final class ProjectLoader: Sendable {
    var encoder: DocumentEncoder?
    
    var modifiedDate: Date
    var url: URL
    var loadingDocument: DocumentLoadingStatus = .initialized
    var thumbnail: UIImage?

    /// Initialzes object with some URL, not yet loading document until loaded in lazy view.
    init(url: URL) {
        // log("ProjectLoader: init: url: \(url)")
        self.url = url

        // Sort URLS by project modification date, excluding metadata changes
        self.modifiedDate = url
            .getLastModifiedDate(fileManager: FileManager.default)
    }
}

extension ProjectLoader: Identifiable {
    var id: Int { self.url.hashValue }
    
    func resetData() {
        self.loadingDocument = .loading
        self.thumbnail = nil
    }
}

extension [ProjectLoader] {
    func sortByDate() -> Self {
        self.sorted { $0.modifiedDate > $1.modifiedDate }
    }
}
