//
//  StitchFileManagerProject.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/21/22.
//

import Foundation
import StitchSchemaKit

/// Helpers focused on reading/writing with a specific project URL.
extension DocumentEncodable {    
    nonisolated func getFolderUrl(for subfolder: StitchEncodableSubfolder,
                                  isTemp: Bool = false) -> URL {
        if isTemp {
            return StitchFileManager.tempDocumentResources.appendingPathComponent(subfolder.rawValue)
        }
        
        return self.rootUrl.appendingPathComponent(subfolder.rawValue)
    }
    
    /// Gets in-use and temp resources for a specific file type.
    func getAllResources(for subfolder: StitchEncodableSubfolder) throws -> [URL] {
        try Self.getAllResources(rootUrl: self.rootUrl,
                                 subfolder: subfolder)
    }
    
    /// Gets in-use and temp resources for a specific file type.
    static func getAllResources(rootUrl: URL,
                                subfolder: StitchEncodableSubfolder,
                                includeTempFiles: Bool = false) throws -> [URL] {
        // Skip if unsupported here
        guard Self.CodableDocument.subfolders.contains(subfolder) else { return [] }
        
        let mainUrl = rootUrl.appendingPathComponent(subfolder.rawValue)
        let tempUrl = StitchFileManager.tempDocumentResources.appendingPathComponent(subfolder.rawValue)
        return try Self.getAllResources(mainDir: mainUrl, tempDir: tempUrl)
    }
    
    /// Gets in-use and temp resources for a specific file type.
    static func getAllResources(mainDir: URL,
                                tempDir: URL?) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: mainDir.path) else { return [] }
        
        let mainResources = try FileManager.default
            .contentsOfDirectory(at: mainDir,
                                 includingPropertiesForKeys: nil)
        
        guard let tempDir = tempDir else { return mainResources }
        
        let tempResources = (try? FileManager.default
            .contentsOfDirectory(at: tempDir,
                                 includingPropertiesForKeys: nil)) ?? []
        
        return mainResources + tempResources
    }
    
    @MainActor
    func readAllImportedFiles() throws -> StitchDocumentDirectory {
        try Self.readAllImportedFiles(rootUrl: self.rootUrl)
    }
    
    static func readAllImportedFiles(rootUrl: URL) throws -> StitchDocumentDirectory {
        // Gets temp URLs as well
        let importedFilesDir = try Self.getAllResources(rootUrl: rootUrl,
                                                        subfolder: .media,
                                                        includeTempFiles: true)
        
        let componentFilesDir = try Self.getAllResources(rootUrl: rootUrl,
                                                         subfolder: .components)
        
        return .init(importedMediaUrls: importedFilesDir,
                     componentDirs: componentFilesDir)
    }

    nonisolated func copyToMediaDirectory(originalURL: URL,
                                          forRecentlyDeleted: Bool,
                                          customMediaKey: MediaKey? = nil) -> URLResult {
        let importedFilesURL = self.getFolderUrl(for: .media, isTemp: forRecentlyDeleted)
        return Self.copyToMediaDirectory(originalURL: originalURL,
                                         importedFilesURL: importedFilesURL,
                                         customMediaKey: customMediaKey)
    }

    /// Copies to imported files uing a custom MediaKey, rather than re-using the same key from the original URL.
    static func copyToMediaDirectory(originalURL: URL,
                                     importedFilesURL: URL,
                                     customMediaKey: MediaKey? = nil) -> URLResult {
        let _ = originalURL.startAccessingSecurityScopedResource()

        // Create media key for destination file
        let destinationMediaKey = customMediaKey ?? originalURL.mediaKey

        switch self.createMediaFileURL(from: destinationMediaKey,
                                       importedFilesURL: importedFilesURL) {
        case .success(let newURL):
            do {
                try FileManager.default.copyItem(at: originalURL, to: newURL)
                originalURL.stopAccessingSecurityScopedResource()
                return .success(newURL)
            } catch {
                log("StitchFileManager.copyToMediaDirectory error: \(error)")
                return .failure(.mediaCopiedFailed)
            }

        case .failure(let error):
            originalURL.stopAccessingSecurityScopedResource()
            return .failure(error)
        }
    }

    static func createMediaFileURL(from mediaKey: MediaKey,
                                   importedFilesURL: URL) -> URLResult {
        guard let mediaType = mediaKey.getMediaType() else {
            return .failure(.mediaFileUnsupported(mediaKey.fileExtension))
        }
        
        // Create ImportedFiles url if it doesn't exist
        let _ = try? StitchFileManager.createDirectories(at: importedFilesURL,
                                                         withIntermediate: true)

        let uniqueName = createUniqueFilename(filename: mediaKey.filename,
                                              mediaType: mediaType,
                                              mediaDirectory: importedFilesURL)

        let newURL = importedFilesURL
            .appendingPathComponent(uniqueName)
            .appendingPathExtension(mediaKey.fileExtension)


        return .success(newURL)
    }

    /// Generates a unique file name for the project's imported files directory.
    static func createUniqueFilename(filename: String,
                                     mediaType: SupportedMediaFormat,
                                     mediaDirectory: URL) -> String {
        do {
            let existingFileNames = try FileManager.default.contentsOfDirectory(at: mediaDirectory,
                                                                                includingPropertiesForKeys: nil)
                .map { $0.filename }
            
            return Stitch.createUniqueFilename(filename: filename,
                                               existingFilenames: existingFileNames,
                                               mediaType: mediaType)
        } catch {
            fatalErrorIfDebug(error.localizedDescription)
            return filename
        }
    }
    
    /// Copies files from another directory.
    nonisolated func copyFiles(from directory: StitchDocumentDirectory) {
        // Copy selected media
        for mediaUrl in directory.importedMediaUrls {
            switch self.copyToMediaDirectory(originalURL: mediaUrl,
                                             forRecentlyDeleted: false) {
            case .success:
                continue
            case .failure(let error):
                log("SelectedGraphItemsPasted error: could not get imported media URL.")
                DispatchQueue.main.async {
                    dispatch(DisplayError(error: error))
                }
            }
        }
        
        for srcComponentUrl in directory.componentDirs {
            let srcUrl = srcComponentUrl
            
            // Clipboard uses non-document root url
            let destRootUrl = self.rootUrl// self.saveLocation.documentSaveLocation?.getRootDirectoryUrl() ?? self.rootUrl
            let destUrl = destRootUrl
                .appendingComponentsPath()
                .appendingPathComponent(srcComponentUrl.lastPathComponent)

            StitchComponent.createUnzippedFileWrapper(folderUrl: destUrl)
            
            StitchComponent.copySubfolders(srcRootUrl: srcUrl,
                                           destRootUrl: destUrl)

            // Fail silently if already exists
            try? FileManager.default.copyItem(at: srcUrl.appendingVersionedSchemaPath(),
                                              to: destUrl.appendingVersionedSchemaPath())
        }
    }
    
    func removeContents() throws {
        try FileManager.default.removeItem(at: self.rootUrl)
    }
}
