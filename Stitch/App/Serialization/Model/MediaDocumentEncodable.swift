//
//  MediaDocumentEncodable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation

protocol MediaDocumentEncodable: Codable {
//    var rootUrl: URL { get }
    func getEncodingUrl(documentRootUrl: URL) -> URL
    static var fileWrapper: FileWrapper { get }
}

extension MediaDocumentEncodable {
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
