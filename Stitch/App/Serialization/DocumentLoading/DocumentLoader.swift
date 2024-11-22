//
//  DocumentLoader.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/25/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

actor DocumentLoader {
    var storage: [URL: ProjectLoader] = [:]

    func directoryUpdated() -> [ProjectLoader]? {
        switch StitchFileManager
            .readDirectoryContents(StitchFileManager.documentsURL.url) {
        case .success(let urls):
            // log("StitchStore.directoryUpdated: urls: \(urls)")
            let filtered = urls
                .filter { [STITCH_EXTENSION_RAW, STITCH_PROJECT_EXTENSION_RAW].contains($0.pathExtension) }

            // Update data
            self.storage = filtered.reduce(into: self.storage) { result, url in
                guard let existingData = result.get(url) else {
                    let data = ProjectLoader(url: url)
                    result.updateValue(data, forKey: url)
                    return
                }

                let updatedDate = url.getLastModifiedDate(fileManager: FileManager.default)
                let wasDocumentUpdated = updatedDate != existingData.modifiedDate

                if wasDocumentUpdated {
                    existingData.modifiedDate = updatedDate

                    // Forces view to refresh
                    Task {
                        await MainActor.run { [weak existingData] in
                            existingData?.loadingDocument = .initialized
                        }                        
                    }
                }
            }

            // Remove deleted documents
            let incomingSet = Set(urls)
            let deletedUrls = Set(storage.keys).subtracting(incomingSet)
            deletedUrls.forEach {
                self.storage.removeValue(forKey: $0)
            }

            return Array(self.storage.values).sortByDate()
            
        case .failure(let error):
            log("DocumentLoader error: failed to get URLs with error: \(error.description)")
            return nil
        }
    }

    nonisolated func loadDocument(from url: URL, 
                                  isImport: Bool = false,
                                  isNonICloudDocumentsFile: Bool = false) async -> DocumentLoadingStatus {
        // Need to be kept for when first renders on screen.
        do {
            guard let document = try await StitchDocument.openDocument(
                from: url,
                isImport: isImport,
                isNonICloudDocumentsFile: isNonICloudDocumentsFile) else {
                
                return .failed
            }
            return .loaded(document)
        } catch {
            log("DocumentLoader.loadDocument error: \(error)")
            return .failed
        }
    }

    nonisolated func loadDocument(_ datedUrl: ProjectLoader, isImport: Bool = false) async {
        let newLoading = await self.loadDocument(from: datedUrl.url, isImport: isImport)

        await MainActor.run { [weak datedUrl] in
            datedUrl?.loadingDocument = newLoading
        }
    }
}

extension DocumentLoader {
    /// Initializer used for new documents.
    func installNewDocument() async throws -> StitchDocument {
        let doc = StitchDocument()
        try await self.installDocument(document: doc)
        return doc
    }

    func installDocument(document: StitchDocument) async throws {
        // Encode projecet directories
        await document.encodeDocumentContents()

        // Create versioned document
        try await self.encodeVersionedContents(document: document)
    }

    // Note: this fails if file does not already exist at path
    func encodeVersionedContents(document: StitchDocument,
                                 directoryUrl: URL? = nil) async throws {
        try Self.encodeDocument(document, to: directoryUrl)

        // Gets home screen to update with latest doc version
        await dispatch(DirectoryUpdated())
    }
    
    static func encodeDocument(_ document: StitchDocument,
                               to directoryURL: URL? = nil) throws {
        // Default directory is known by document, sometimes we use a temp URL
        let directoryURL = directoryURL ?? document.rootUrl
        
        let versionedData = try getStitchEncoder().encode(document)
        let filePath = directoryURL.appendingVersionedSchemaPath()

        try versionedData.write(to: filePath,
                                options: .atomic)
    }
}
