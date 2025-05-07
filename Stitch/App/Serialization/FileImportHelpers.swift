//
//  FileImportHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/6/25.
//

import Foundation
import UniformTypeIdentifiers

// Strong wrapper types to distinguish between the dropped file's URL vs. temporary directory's URL vs. temporary-file's URL
struct TemporaryDirectoryURL: Equatable, Codable, Hashable {
    let value: URL
    
    // Whenever we access the temporary directory,
    // we want to first clear / create it.
    init() {
        let temporaryDirectoryURL: URL = StitchFileManager.importedFilesDir
        
        // Clear previous data
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        
        // Create imported folder if not yet made
        try? FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        
        self.value = temporaryDirectoryURL
    }
}

struct TemporaryURL: Equatable, Codable, Hashable {
    let value: URL
}

extension TemporaryURL {

    // Helpful in cases where we need to download the file, e.g. HTTPS
    // TODO: create a method that checks whether URL is local vs https and copies vs downloads ?
    static func pathOnly(url: URL,
                         _ temporaryDirectoryURL: TemporaryDirectoryURL) -> Self {
        
        let tempURL = temporaryDirectoryURL.value
            .appendingPathComponent(url.filename)
            .appendingPathExtension(url.pathExtension)
        
        return .init(value: tempURL)
    }
        
    // Assumes we've already downloaded the URL, so e.g. a local URL, not an HTTPS
    // Used for drops of local files
    static func pathAndCopy(url: URL,
                            _ temporaryDirectoryURL: TemporaryDirectoryURL) -> Self? {
        
        // MARK: due to async logic of dispatched effects, the provided temporary URL has a tendancy to expire, so a new URL is created.
        let tempURL = Self.pathOnly(url: url,
                                    temporaryDirectoryURL)
        
        let _ = url.startAccessingSecurityScopedResource()
        
        // TODO: this logic is not acceptable if the URL is one that needs to be downloaded first, e.g. `http://...`
        // Default FileManager ok here given we just need a temp URL
        do {
            try FileManager.default.copyItem(at: url, to: tempURL.value)
            url.stopAccessingSecurityScopedResource()
            return tempURL
        } catch {
            url.stopAccessingSecurityScopedResource()
            fatalErrorIfDebug("handleOnDrop error: \(error)")
            return nil
        }
    }
}

extension URL {
    var isStitchDocumentExtension: Bool {
        self.pathExtension == UTType.stitchDocument.preferredFilenameExtension
    }
}
