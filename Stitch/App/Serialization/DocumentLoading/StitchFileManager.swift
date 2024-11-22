//
//  StitchFileManager.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/20/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@Observable
final class StitchFileManager: FileManager, MiddlewareService {
    var syncStatus: iCloudSyncStatus = .offline

    static var documentsURL: DocumentsURL {
        switch getCloudDocumentURL() {
        case .success(let documentsURL):
            return documentsURL
        case .failure(let error):
            log("getDocumentsURL: failed to retrieve cloud documents: \(error)")
            return getLocalDocumentURL()
        }
    }

    static var tempDir: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    /// File removal abstraction which enables possible usage of temporary storage for recently deleted items, enabling undo/redo support on deleted files.
    private static func removeItem(at URL: URL) -> StitchFileVoidResult {
        do {
            try Self.default.removeItem(at: URL)
        } catch {
            log("removeStitchItem error: \(error)")
            return .failure(.deleteFileFailed)
        }

        return .success
    }

    static func removeStitchMedia(at URL: URL,
                                  currentProject: StitchDocumentIdentifiable,
                                  permanently: Bool = false) async -> StitchFileVoidResult {
        if !permanently {
            // Copy file to recentely deleted URL
            let _ = await self.copyToMediaDirectory(originalURL: URL,
                                                    in: currentProject,
                                                    forRecentlyDeleted: true)
        }
        return Self.removeItem(at: URL)
    }

    @MainActor
    static func removeStitchProject(url: URL,
                                    projectId: ProjectId,
                                    permanently: Bool = false) -> StitchFileVoidResult {
        
        // let _ = url.startAccessingSecurityScopedResource()
        
        // TODO: fix 'Undo Delete' on iPhone
        let allowUndo = !permanently && !isPhoneDevice()
        
        if allowUndo {
            
            log("StitchFileManager.removeStitchProject: Will non-permanently delete StitchProject \(projectId) at url \(url)")
            
             log("StitchFileManager.removeStitchProject: url.absoluteString \(url.absoluteString)")

            // Remove any possibly existing file with same name
            let recentlyDeletedProjectUrl = StitchDocument.recentlyDeletedURL
                .appendingStitchProjectDataPath(projectId)
            
             log("StitchFileManager.removeStitchProject: recentlyDeletedProjectUrl: \(recentlyDeletedProjectUrl)")
            
            // Silently fail if it doesn't exist
//            try! Self.default.removeItem(at: recentlyDeletedProjectUrl)
            if let _ = try? Self.default.removeItem(at: recentlyDeletedProjectUrl) {
                log("StitchFileManager.removeStitchProject: failed to delete \(recentlyDeletedProjectUrl)")
            }
            
            do {
                // Save to recently deleted
                // TODO: Encode project on removal
                //                fatalError()
                
                try Self.default.moveItem(at: url,
                                          to: recentlyDeletedProjectUrl)
                
                //                try Self.default.moveItem(atPath: url.absoluteString,
                //                                          toPath: recentlyDeletedProjectUrl.absoluteString)
                
                //                try self.moveItem(at: url,
                //                                  to: recentlyDeletedProjectUrl)
            } catch {
                log("StitchFileManager.removeStitchProject error: \(error)")
                return .failure(.deleteFileFailed)
            }
        } else {
            log("StitchFileManager.removeStitchProject: Will permanently delete StitchProject \(projectId) at url \(url)")
            do {
                try Self.default.removeItem(at: url)
            } catch {
                log("StitchFileManager.removeStitchProject error: \(error)")
                return .failure(.deleteFileFailed)
            }
        }
        
        // url.stopAccessingSecurityScopedResource()
        
        return .success
    }

    static func getMediaURL(for mediaKey: MediaKey,
                            document: StitchDocumentIdentifiable,
                            forRecentlyDeleted: Bool) -> URLResult {

        let importedFiles = Self.readMediaFilesDirectory(document: document,
                                                         forRecentlyDeleted: forRecentlyDeleted)

        guard let url = importedFiles.first(where: { $0.mediaKey == mediaKey }) else {
            return .failure(.mediaNotFoundInLibrary)
        }

        return .success(url)
    }

    /// Zips contents of self to new URL.
    func zip(from fromURL: URL, to: URL) -> StitchFileVoidResult {
        do {
            try self.zipItem(at: fromURL, to: to)
            return .success
        } catch {
            log("zip: failed with \(error)")
            return .failure(.zipFailed(error))
        }
    }

    // Succeeds even in offline mode.
    // Fails just when iCloud Drive is disabled for Stitch or in general.
    static func getCloudDocumentURL() -> StitchFileResult<DocumentsURL> {
        #if LOCAL_ONLY
        return .failure(.cloudDocsContainerNotFound)
        #else

        guard let url = Self.default.url(forUbiquityContainerIdentifier: nil) else {
            return .failure(.cloudDocsContainerNotFound)
        }
        return .success(DocumentsURL(url: url.appendingPathComponent("Documents")))
        #endif
    }
    
    static func getLocalDocumentURL() -> DocumentsURL {
        let paths = Self.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory: URL = paths[0]
        return DocumentsURL(url: documentsDirectory)
    }

    static func cloudEnabled() -> Bool {
        #if LOCAL_ONLY
        false
        #else
        !Self.getCloudDocumentURL().isFailure
        #endif
    }

    static func readDirectoryContents(_ directoryURL: URL) -> DirectoryContentsResult {
        do {
            let urls = try Self.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil)
            return .success(urls)
        } catch {
            log("readDirectoryContents error: \(error)")
            return .failure(.documentsDirUnreadable)
        }
    }

    // create the project dir, if it doesn't already exist
    static func createDirectories(at url: URL, withIntermediate: Bool) async throws {
        if !FileManager.default.fileExists(atPath: url.relativePath) {
            log("createDirectories: will create dir")

            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: withIntermediate,
                attributes: nil)
        }
    }
}
