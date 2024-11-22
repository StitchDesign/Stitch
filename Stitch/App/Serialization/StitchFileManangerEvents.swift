//
//  StitchFileManangerEvents.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/21/22.
//

import Foundation
import StitchSchemaKit

extension GraphState: StitchDocumentIdentifiable { }

extension DocumentEncoder {
    func deleteMediaFromNode(mediaKey: MediaKey) async {
        switch await StitchFileManager.getMediaURL(for: mediaKey,
                                                   document: self.lastEncodedDocument,
                                                   forRecentlyDeleted: false) {
        case .success(let url):
            let _ = await StitchFileManager.removeStitchMedia(at: url,
                                                              currentProject: self.lastEncodedDocument)

        case .failure(let error):
            // Silently report error
            log("deleteMediaFromNodeEffect error: could not find library substate with error: \(error)")
        }
    }
}

extension GraphState {
    /// Called when GraphState is initialized to build library data and then run first calc.
    func graphInitialized(document: StitchDocument) async {
        let importedFilesDir = await StitchFileManager.getAllMediaURLs(in: self.createSchema().getImportedFilesURL())

        // Start graph once library is built
        await MainActor.run { [weak self] in
            self?.importedFilesDirectoryReceived(importedFilesDir: importedFilesDir,
                                                 document: document)
        }
    }
}
