//
//  StitchFileManangerEvents.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/21/22.
//

import Foundation
import StitchSchemaKit

//extension GraphState: StitchDocumentIdentifiable { }

extension DocumentEncodable {
    func deleteMediaFromNode(mediaKey: MediaKey) async {
        switch self.getMediaURL(for: mediaKey,
                                forRecentlyDeleted: false) {
        case .success(let url):
            let _ = await self.removeStitchMedia(at: url)

        case .failure(let error):
            // Silently report error
            log("deleteMediaFromNodeEffect error: could not find library substate with error: \(error)")
        }
    }

    /// Called when GraphState is initialized to build library data and then run first calc.
    func graphInitialized() async {
        let importedFilesDir = await DocumentEncoder
            .getAllMediaURLs(in: self.getImportedFilesURL())

        let lastEncodedDocument = self.lastEncodedDocument
        
        fatalError("need published components")
        
        // Start graph once library is built
        await MainActor.run { [weak self] in
            guard let encoder = self else {
                return
            }
            
            encoder.delegate?.importedFilesDirectoryReceived(importedFilesDir: importedFilesDir,
                                                             publishedComponents: [])
        }
    }
}
