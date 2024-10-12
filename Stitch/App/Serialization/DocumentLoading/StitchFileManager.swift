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
    static let importedFilesDir = StitchFileManager.tempDir.appendingPathComponent("ImportedData")
    static let exportedFilesDir = StitchFileManager.tempDir.appendingPathComponent("ExportedData")
    
    var syncStatus: iCloudSyncStatus = .offline
    
    static var documentsURL: URL {
        switch getCloudKitRootURL() {
        case .success(let documentsURL):
            return documentsURL
                .appendingPathComponent("Documents")
        case .failure(let error):
            log("getDocumentsURL: failed to retrieve cloud documents: \(error)")
            return getLocalDocumentURL()
        }
    }
    
    static var tempDir: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Stitch")
    }
    
    /// File removal abstraction which enables possible usage of temporary storage for recently deleted items, enabling undo/redo support on deleted files.
    static func removeItem(at URL: URL) -> StitchFileVoidResult {
        do {
            try Self.default.removeItem(at: URL)
        } catch {
            log("removeStitchItem error: \(error)")
            return .failure(.deleteFileFailed)
        }
        
        return .success
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
    static func getCloudKitRootURL() -> URLResult {
        #if LOCAL_ONLY
        return .failure(.cloudDocsContainerNotFound)
        #else

        guard let url = Self.default.url(forUbiquityContainerIdentifier: nil) else {
            return .failure(.cloudDocsContainerNotFound)
        }
        return .success(url)
        #endif
    }
    
    static func getLocalDocumentURL() -> URL {
        let paths = Self.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory: URL = paths[0]
        return documentsDirectory
    }

    static func cloudEnabled() -> Bool {
        #if LOCAL_ONLY
        false
        #else
        !Self.getCloudKitRootURL().isFailure
        #endif
    }

    static func readDirectoryContents(_ directoryURL: URL) -> DirectoryContentsResult {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil)
            return .success(urls)
        } catch {
            log("readDirectoryContents error: \(error)")
            return .failure(.documentsDirUnreadable)
        }
    }

    // create the project dir, if it doesn't already exist
    static func createDirectories(at url: URL, withIntermediate: Bool) throws {
        if !FileManager.default.fileExists(atPath: url.relativePath) {
            log("createDirectories: will create dir")

            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: withIntermediate,
                attributes: nil)
        }
    }
    
    @MainActor
    static func removeStitchProject(url: URL,
                                    projectId: UUID,
                                    permanently: Bool = false) -> StitchFileVoidResult {
        
        // let _ = url.startAccessingSecurityScopedResource()
        
        // TODO: fix 'Undo Delete' on iPhone
        let allowUndo = !permanently && !isPhoneDevice()
        
        if allowUndo {
            log("StitchFileManager.removeStitchProject: Will non-permanently delete StitchProject \(projectId)")
            
            // Wipe directory for recently deleted projects
            try? FileManager.default.removeItem(at: StitchFileManager.recentlyDeletedURL)
            try? FileManager.default.createDirectory(at: StitchFileManager.recentlyDeletedURL,
                                                     withIntermediateDirectories: true)

            let recentlyDeletedProjectUrl = StitchFileManager.recentlyDeletedURL
                .appendingStitchProjectDataPath("\(projectId)")
            
            do {
                // Save to recently deleted
                try StitchFileManager.default.moveItem(at: url,
                                                       to: recentlyDeletedProjectUrl)
            } catch {
                log("StitchFileManager.removeStitchProject error: \(error)")
                return .failure(.deleteFileFailed)
            }
        } else {
            log("StitchFileManager.removeStitchProject: Will permanently delete StitchProject \(projectId)")
            do {
                try StitchFileManager.default.removeItem(at: url)
            } catch {
                log("StitchFileManager.removeStitchProject error: \(error)")
                return .failure(.deleteFileFailed)
            }
        }
        
        // url.stopAccessingSecurityScopedResource()
        
        return .success
    }
}

extension DocumentEncodable {
    func removeStitchMedia(at URL: URL,
                           permanently: Bool = false) -> StitchFileVoidResult {
        if !permanently {
            // Copy file to recentely deleted URL
            let _ = self.copyToMediaDirectory(originalURL: URL,
                                              forRecentlyDeleted: true)
        }
        return StitchFileManager.removeItem(at: URL)
    }
    
    func getMediaURL(for mediaKey: MediaKey) -> URLResult {
        do {
            let importedFiles = try self.getAllResources(for: .media)
            
            guard let url = importedFiles.first(where: { $0.mediaKey == mediaKey }) else {
                return .failure(.mediaNotFoundInLibrary)
            }
            
            return .success(url)
        } catch {
            fatalErrorIfDebug("getMediaURL: \(error.localizedDescription)")
            return .failure(.mediaNotFoundInLibrary)
        }
    }
}
