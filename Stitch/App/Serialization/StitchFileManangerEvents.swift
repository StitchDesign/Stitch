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

        // Find and migrate each installed component
        let publishedDocumentComponentsDir = self.componentsDirUrl
        // Components might not exist so fail quietly
        let components = (try? StitchComponent.migrateEncodedComponents(at: publishedDocumentComponentsDir)) ?? []

        let lastEncodedDocument = self.lastEncodedDocument
        
        
        // Start graph once library is built
        await MainActor.run { [weak self] in
            guard let encoder = self else {
                return
            }
            
            encoder.delegate?.importedFilesDirectoryReceived(importedFilesDir: importedFilesDir,
                                                             publishedComponents: components)
        }
    }
}
