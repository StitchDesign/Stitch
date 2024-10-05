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
    
    func updateStorage(with projectLoader: ProjectLoader) {
        self.storage.updateValue(projectLoader, forKey: projectLoader.url)
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
            
            // thumbnail loading not needed for import
            let thumbnail = isImport ? nil : DocumentEncoder.getProjectThumbnailImage(rootUrl: url)
            
            return .loaded(document, thumbnail)
        } catch {
            log("DocumentLoader.loadDocument error: \(error)")
            return .failed
        }
    }

    nonisolated func loadDocument(_ projectLoader: ProjectLoader,
                                  isImport: Bool = false) async {
        let newLoading = await self.loadDocument(from: projectLoader.url, isImport: isImport)

        await MainActor.run { [weak projectLoader] in
            projectLoader?.loadingDocument = newLoading
        }
    }
    
    func refreshDocument(url: URL) async {
        guard let projectLoader = self.storage.get(url) else { return }
        
        projectLoader.resetData()
        await self.loadDocument(projectLoader)
    }
}

extension DocumentLoader {
    func createNewProject(from document: StitchDocument = .init(),
                          isPhoneDevice: Bool,
                          store: StitchStore) async throws {
        let projectLoader = try await self.installDocument(document: document)
        projectLoader.loadingDocument = .loaded(document, nil)
        
        self.updateStorage(with: projectLoader)
        
        let document = await StitchDocumentViewModel(
            from: document,
            isPhoneDevice: isPhoneDevice,
            projectLoader: projectLoader,
            store: store
        )

        document?.didDocumentChange = true // creates fresh thumbnail
        
        await MainActor.run { [weak document, weak store] in
            guard let document = document else { return }
            
            // Get latest preview window size
            let previewDeviceString = UserDefaults.standard.string(forKey: DEFAULT_PREVIEW_WINDOW_DEVICE_KEY_NAME) ??
            PreviewWindowDevice.defaultPreviewWindowDevice.rawValue
            
            guard let previewDevice = PreviewWindowDevice(rawValue: previewDeviceString) else {
                fatalErrorIfDebug()
                return
            }
            
            document.previewSizeDevice = previewDevice
            document.previewWindowSize = previewDevice.previewWindowDimensions
            store?.navPath = [document]
        }
    }

    func installDocument(document: StitchDocument) async throws -> ProjectLoader {
        let rootUrl = document.rootUrl
        let projectLoader = ProjectLoader(url: rootUrl)
        
        self.storage.updateValue(projectLoader,
                                 forKey: rootUrl)
        
        // Encode projecet directories
        await document.encodeDocumentContents(documentRootUrl: rootUrl)

        // Create versioned document
        try Self.encodeDocument(document, to: rootUrl)
        
        projectLoader.loadingDocument = .loaded(document, nil)
        return projectLoader
    }
    
    static func encodeDocument(_ document: StitchDocument) throws {
        try Self.encodeDocument(document, to: document.rootUrl)
    }
    
    static func encodeDocument<Document>(_ document: Document,
                                         to directoryURL: URL) throws where Document: StitchDocumentEncodable {
        // Default directory is known by document, sometimes we use a temp URL
        let directoryURL = document.getEncodingUrl(documentRootUrl: directoryURL)
        
        let versionedData = try getStitchEncoder().encode(document)
        let filePath = directoryURL.appendingVersionedSchemaPath()

        try versionedData.write(to: filePath,
                                options: .atomic)
    }
}
