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

/// Used for `StitchDocument` and `StitchComponent`
protocol StitchDocumentEncodable: Codable, Identifiable, Transferable where VersionType.NewestVersionType == Self {
    associatedtype VersionType: StitchSchemaVersionType
    
    static var fileType: UTType { get }
    static var fileWrapper: FileWrapper { get }

    init()
    var rootUrl: URL { get }
    var id: UUID { get set }
    var name: String { get }
    
    func getEncodingUrl(documentRootUrl: URL) -> URL
}

extension StitchDocumentEncodable {
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

struct StitchDocumentSubdirectoryFiles {
    let importedMediaUrls: [URL]
    let componentUrls: [URL]
}
