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

final actor DocumentLoader {
    var userProjects: [URL: ProjectLoader] = [:]

    func directoryUpdated() async -> StitchDirectoryResponse? {
        switch StitchFileManager
            .readDirectoryContents(StitchFileManager.documentsURL) {
        case .success(let urls):
            // log("StitchStore.directoryUpdated: urls: \(urls)")
            let documentUrls = urls
                .filter { $0.pathExtension == UTType.stitchProjectData.preferredFilenameExtension }
            
            let systemUrls = urls
                .filter { $0.pathExtension == UTType.stitchSystemUnzipped.preferredFilenameExtension }

            var updatedUserProjects = [URL: ProjectLoader]()
            
            // Update data
            for url in documentUrls {
                guard let existingData = self.userProjects.get(url) else {
                    let data = await ProjectLoader(url: url)
                    updatedUserProjects.updateValue(data, forKey: url)
                    continue
                }

                let updatedDate = url.getLastModifiedDate(fileManager: FileManager.default)
                let existingModifiedDate = await existingData.modifiedDate
                let wasDocumentUpdated = updatedDate != existingModifiedDate
                updatedUserProjects.updateValue(existingData, forKey: url)
                
                if wasDocumentUpdated {
                    Task { @MainActor [weak existingData] in
                        existingData?.modifiedDate = updatedDate
                        
                        // Forces view to refresh
                        existingData?.loadingDocument = .initialized
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
            let deletedUrls = Set(userProjects.keys).subtracting(incomingSet)
            deletedUrls.forEach {
                updatedUserProjects.removeValue(forKey: $0)
            }

            let sortedProjects = updatedUserProjects
                .sorted {
                    $0.key.getLastModifiedDate(fileManager: FileManager.default) >
                    $1.key.getLastModifiedDate(fileManager: FileManager.default)
                }
                .map { $0.value }
            
            self.userProjects = updatedUserProjects
            
            return .init(projects: sortedProjects,
                         systems: systems)
            
        case .failure(let error):
            log("DocumentLoader error: failed to get URLs with error: \(error.description)")
            return nil
        }
    }
    
    func updateStorage(with projectLoader: ProjectLoader,
                       url: URL) {
        self.userProjects.updateValue(projectLoader, forKey: url)
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
        guard let projectLoader = self.userProjects.get(url) else { return }
        
        await projectLoader.resetData()
        await self.loadDocument(projectLoader)
    }
}

extension DocumentLoader {
    @MainActor
    func createNewProject(from document: StitchDocument = .init(),
                          isProjectImport: Bool,
                          enterProjectImmediately: Bool = true,
                          store: StitchStore) async throws {
        let projectLoader = try await self.installDocument(document: document)
        
        await self.updateStorage(with: projectLoader,
                                 url: document.rootUrl)
        
        let documentViewModel = await StitchDocumentViewModel(
            from: document,
            projectLoader: projectLoader,
            store: store,
            isDebugMode: false
        )
        
        documentViewModel?.didDocumentChange = true // creates fresh thumbnail
        
        // TODO: why and how can this fail? Should we have a `fatalErrorIfDebug here?
        guard let documentViewModel = documentViewModel else { return }
        
        projectLoader.loadingDocument = .loaded(document, nil)
        
        if isProjectImport {
            documentViewModel.previewSizeDevice = document.previewSizeDevice
            documentViewModel.previewWindowSize = document.previewWindowSize
        } else {
            // Get latest preview window size
            let previewDevice = UserDefaults.standard.string(forKey: DEFAULT_PREVIEW_WINDOW_DEVICE_KEY_NAME)
                .flatMap { PreviewWindowDevice(rawValue: $0) }
            ?? PreviewWindowDevice.defaultPreviewWindowDevice
            
            documentViewModel.previewSizeDevice = previewDevice
            documentViewModel.previewWindowSize = previewDevice.previewWindowDimensions
        }
        
        if enterProjectImmediately {
            projectLoader.documentViewModel = documentViewModel
            store.navPath = [projectLoader]
        }
    }

    func installDocument(document: StitchDocument) async throws -> ProjectLoader {
        let rootUrl = document.rootUrl
        let projectLoader = await ProjectLoader(url: rootUrl)
        
        try document.installDocument()
        
        await MainActor.run { [weak projectLoader] in
            projectLoader?.encoder = .init(document: document)
            projectLoader?.loadingDocument = .loaded(document, nil)
        }

        self.userProjects.updateValue(projectLoader,
                                 forKey: rootUrl)
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
