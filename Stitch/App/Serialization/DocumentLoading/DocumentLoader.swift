//
//  DocumentLoader.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/25/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import UniformTypeIdentifiers

struct StitchDirectoryResponse {
    let projects: [ProjectLoader]
    let systems: [StitchSystem]
}

actor DocumentLoader {
    var storage: [URL: ProjectLoader] = [:]

    func directoryUpdated() async -> StitchDirectoryResponse? {
        switch StitchFileManager
            .readDirectoryContents(StitchFileManager.documentsURL) {
        case .success(let urls):
            // log("StitchStore.directoryUpdated: urls: \(urls)")
            let documentUrls = urls
                .filter { $0.pathExtension == UTType.stitchProjectData.preferredFilenameExtension }
            
            let systemUrls = urls
                .filter { $0.pathExtension == UTType.stitchSystemUnzipped.preferredFilenameExtension }

            // Update data
            self.storage = documentUrls.reduce(into: self.storage) { result, url in
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
            
            var systems: [StitchSystem] = []
            for systemUrl in systemUrls {
                do {
                    if let system = try await StitchSystem.openDocument(from: systemUrl) {
                        systems.append(system)
                    }
                } catch {
                    log("DocumentLoader.directoryUpdated system error: \(error.localizedDescription)")
                }
            }

            // Remove deleted documents
            let incomingSet = Set(urls)
            let deletedUrls = Set(storage.keys).subtracting(incomingSet)
            deletedUrls.forEach {
                self.storage.removeValue(forKey: $0)
            }

            let sortedProjects = Array(self.storage.values).sortByDate()
            return .init(projects: sortedProjects,
                         systems: systems)
            
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
            // Create an encoder if not yet created
            if projectLoader?.encoder == nil,
                let document = newLoading.document {
                projectLoader?.encoder = DocumentEncoder(document: document)
            }
    
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
        let projectLoader = try self.installDocument(document: document)
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

    func installDocument(document: StitchDocument) throws -> ProjectLoader {
        let rootUrl = document.rootUrl
        let projectLoader = ProjectLoader(url: rootUrl)
        projectLoader.encoder = .init(document: document)
        
        try document.installDocument()
        
        self.storage.updateValue(projectLoader,
                                 forKey: rootUrl)
        
        projectLoader.loadingDocument = .loaded(document, nil)
        return projectLoader
    }
    
}

extension StitchDocumentEncodable {
    func installDocument() throws {        
        // Create project directories
        self.createUnzippedFileWrapper()

        // Create versioned document
        try Self.encodeDocument(self)
    }
}
