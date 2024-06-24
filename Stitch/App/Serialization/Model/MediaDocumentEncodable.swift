//
//  MediaDocumentEncodable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation

protocol MediaDocumentEncodable {
    var rootUrl: URL { get }
    static var fileWrapper: FileWrapper { get }
}

extension MediaDocumentEncodable {
    /// Initializer used for a new project, which creates file paths for contents like media.
    func encodeDocumentContents() async {
        let folderUrl = self.rootUrl

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
