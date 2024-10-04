//
//  MediaDocumentEncodable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import StitchSchemaKit

protocol StitchDocumentMigratable: Transferable, StitchDocumentEncodable where VersionType.NewestVersionType == Self {
    associatedtype VersionType: StitchSchemaVersionType
    
    static var zippedFileType: UTType { get }
}

extension StitchDocumentMigratable {
    static func getDocument(from url: URL) throws -> Self? {
        guard let doc = try Self.VersionType.migrate(versionedCodableUrl: url) else {
            //                #if DEBUG
            //                fatalError()
            //                #endif
            log("StitchDocumentMigratable.getDocument: could not migrate")
            return nil
        }
        
        return doc
    }
}

/// Used for `StitchDocument` and `StitchComponent`
protocol StitchDocumentEncodable: Codable, Identifiable {
    static var unzippedFileType: UTType { get }
    static var fileWrapper: FileWrapper { get }

    init()
    var rootUrl: URL { get }
    var id: UUID { get set }
    var name: String { get }
    
    func getEncodingUrl(documentRootUrl: URL) -> URL
    static func getDocument(from url: URL) throws -> Self?
}

extension StitchDocumentEncodable {
    static var subfolderNames: [String] {
        [
            STITCH_IMPORTED_FILES_DIR,
            URL.componentsDirPath
        ]
    }
    
    /// Initializer used for a new project, which creates file paths for contents like media.
    func encodeDocumentContents(documentRootUrl: URL) async {
        // Creates new paths with subfolders if relevant (i.e. components)
        let folderUrl = self.getEncodingUrl(documentRootUrl: documentRootUrl)
        
        await self.encodeDocumentContents(folderUrl: folderUrl)
    }
     
    /// Invoked when full path is known.
    func encodeDocumentContents(folderUrl: URL) async {
        // Only proceed if folder doesn't exist
        guard !FileManager.default.fileExists(atPath: folderUrl.path) else {
            return
        }

        do {
            // Create file wrapper which creates the .stitch folder
            try Self.fileWrapper.write(to: folderUrl,
                                       originalContentsURL: nil)
        } catch {
            log("StitchDocumentWrapper.init error: \(error.localizedDescription)")
        }
    }

    static var fileWrapper: FileWrapper {
        FileWrapper(directoryWithFileWrappers: [:])
    }
}

struct StitchDocumentDirectory: Equatable {
    let importedMediaUrls: [URL]
    let componentDirs: [URL]
}

extension StitchDocumentDirectory {
    static var empty: Self {
        self.init(importedMediaUrls: [],
                  componentDirs: [])
    }
    
    var isEmpty: Bool {
        self == .empty
    }
}
