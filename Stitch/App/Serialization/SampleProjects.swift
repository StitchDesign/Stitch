//
//  SampleProjects.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/6/25.
//

import Foundation
import UniformTypeIdentifiers


// Helper for downloading files from HTTP/HTTPS urls
func downloadFile(from url: URL,
                  to destinationURL: URL) async throws -> URL {
    
    let (tempLocalURL, _) = try await URLSession.shared.download(from: url)

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
    }
    try fileManager.moveItem(at: tempLocalURL, to: destinationURL)

    return destinationURL
}

// Used by modal that imports a single sample project.
func importStitchSampleProject(sampleProjectURL: URL,
                               store: StitchStore) async throws {
    
    log("importStitchSampleProjectSideEffect: sampleProjectURL: \(sampleProjectURL)")
        
    do {
        let tempURL = TemporaryURL.pathOnly(url: sampleProjectURL, TemporaryDirectoryURL())
        
        let savedURL = try await downloadFile(from: sampleProjectURL, to: tempURL.value)
        log("savedURL: \(savedURL)")
        
        let openedDocument = try await StitchDocument.openDocument(
            from: savedURL,
            isImport: true,
            // i.e. do not attempt ubiquitous-download
            isNonICloudDocumentsFile: true)
        
        guard let openedDocument = openedDocument else {
            DispatchQueue.main.async {
                log("importStitchSampleProjectSideEffect: unsupported project")
                dispatch(DisplayError(error: .unsupportedProject))
            }
            return
        }
        
        log("importStitchSampleProjectSideEffect: will open project from document")
        await store.createNewProject(
            from: openedDocument,
            isProjectImport: true,
            enterProjectImmediately: true)
        
    } catch {
        log("importStitchSampleProjectSideEffect: Download failed: \(error)")
        throw error
    }
}

extension StitchStore {
    /// Conditionally show modal if project URLs are non-empty. Else, we show the empty projects experience.
    @MainActor
    func conditionallToggleSampleProjectsModal() {
        let containsProjects = !(self.allProjectUrls?.isEmpty ?? true)
        
        // Always allow toggling to false
        if self.showsSampleProjectModal {
            self.showsSampleProjectModal = false
            return
        }
        
        self.showsSampleProjectModal = containsProjects
    }
}
