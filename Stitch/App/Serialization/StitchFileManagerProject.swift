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
    static func getAllMediaURLs(in importedFilesDir: URL) -> [URL] {
        let importedFiles = Self.readMediaFilesDirectory(mediaDirectory: importedFilesDir)

        // use temp directory rather than documentsURL
        let tempFiles = Self.readMediaFilesDirectory(mediaDirectory: StitchDocument.temporaryMediaURL)

        let allMedia = importedFiles + tempFiles
        return allMedia
    }
    
    func getAllMediaURLs() -> [URL] {
        Self.getAllMediaURLs(in: self.getImportedFilesURL())
    }

    func readMediaFilesDirectory(forRecentlyDeleted: Bool) -> [URL] {
        // Assumes usage of DocumentsURL
        let mediaDirectory = self.getImportedFilesURL(forRecentlyDeleted: forRecentlyDeleted)
        return Self.readMediaFilesDirectory(mediaDirectory: mediaDirectory)
    }

    static func readMediaFilesDirectory(mediaDirectory: URL) -> [URL] {
        let readContentsResult = StitchFileManager.readDirectoryContents(mediaDirectory)
        switch readContentsResult {
        case .success(let urls):
            return urls
        case .failure(let error):
            log("readImportedFilesDirectory: unable to read directory contents, creating a new imported files directory.\nerror:\(error)")
            return []
        }
    }
    
    static func readComponentsDirectory(rootUrl: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: rootUrl.appendingComponentsPath(),
                                                      includingPropertiesForKeys: nil)) ?? []
    }
    
    func readAllImportedFiles() -> StitchDocumentDirectory {
        Self.readAllImportedFiles(rootUrl: self.rootUrl)
    }
    
    static func readAllImportedFiles(rootUrl: URL) -> StitchDocumentDirectory {
        let importedFilesDir = Self.getAllMediaURLs(in: rootUrl.appendingStitchMediaPath())
        let componentFilesDir = Self.readComponentsDirectory(rootUrl: rootUrl)
        
        return .init(importedMediaUrls: importedFilesDir,
                     componentDirs: componentFilesDir)
    }

    func copyToMediaDirectory(originalURL: URL,
                              forRecentlyDeleted: Bool,
                              customMediaKey: MediaKey? = nil) -> URLResult {
        let importedFilesURL = self.getImportedFilesURL(forRecentlyDeleted: forRecentlyDeleted)
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
        // Create ImportedFiles url if it doesn't exist
        let _ = try? StitchFileManager.createDirectories(at: importedFilesURL,
                                                         withIntermediate: true)

        let uniqueName = createUniqueFilename(filename: mediaKey.filename,
                                              mediaType: mediaKey.getMediaType(),
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
        let existingFileNames = Self.readMediaFilesDirectory(mediaDirectory: mediaDirectory)
            .map { $0.filename }

        return Stitch.createUniqueFilename(filename: filename,
                                           existingFilenames: existingFileNames,
                                           mediaType: mediaType)
    }
    
    /// Copies files from another directory.
    func copyFiles(from directory: StitchDocumentDirectory,
                   newSaveLocation: GraphSaveLocation?) async {
        // Copy selected media
        for mediaUrl in directory.importedMediaUrls {
            switch self.copyToMediaDirectory(originalURL: mediaUrl,
                                             forRecentlyDeleted: false) {
            case .success:
                continue
            case .failure(let error):
                log("SelectedGraphItemsPasted error: could not get imported media URL.")
                await MainActor.run {
                    dispatch(DisplayError(error: error))
                }
            }
        }
        
        for srcComponentUrl in directory.componentDirs {
            do {
                guard var srcComponent = try await StitchComponent.openDocument(from: srcComponentUrl) else {
                    fatalErrorIfDebug()
                    return
                }
                
                if let newSaveLocation = newSaveLocation {
                    srcComponent.saveLocation = newSaveLocation
                }
                
                try srcComponent.encodeNewDocument(srcRootUrl: srcComponentUrl)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
        }
    }
    
    func removeContents() throws {
        try FileManager.default.removeItem(at: self.rootUrl)
    }
}
