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
    static func getAllMediaURLs(in importedFilesDir: URL) async -> [URL] {
        let importedFiles = Self.readMediaFilesDirectory(mediaDirectory: importedFilesDir)

        // use temp directory rather than documentsURL
        let tempFiles = Self.readMediaFilesDirectory(mediaDirectory: StitchDocument.temporaryMediaURL)

        let allMedia = importedFiles + tempFiles
        return allMedia
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

    func copyToMediaDirectory(originalURL: URL,
                              forRecentlyDeleted: Bool,
                              customMediaKey: MediaKey? = nil) async -> URLResult {
        let importedFilesURL = self.getImportedFilesURL(forRecentlyDeleted: forRecentlyDeleted)
        return await Self.copyToMediaDirectory(originalURL: originalURL,
                                               importedFilesURL: importedFilesURL,
                                               customMediaKey: customMediaKey)
    }

    /// Copies to imported files uing a custom MediaKey, rather than re-using the same key from the original URL.
    static func copyToMediaDirectory(originalURL: URL,
                                     importedFilesURL: URL,
                                     customMediaKey: MediaKey? = nil) async -> URLResult {
        let _ = originalURL.startAccessingSecurityScopedResource()

        // Create media key for destination file
        let destinationMediaKey = customMediaKey ?? originalURL.mediaKey

        switch await self.createMediaFileURL(from: destinationMediaKey,
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
                                   importedFilesURL: URL) async -> URLResult {
        // Create ImportedFiles url if it doesn't exist
        let _ = try? await StitchFileManager.createDirectories(at: importedFilesURL,
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
}
