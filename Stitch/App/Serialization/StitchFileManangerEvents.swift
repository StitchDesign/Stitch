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
        let importedFilesDir = self.readAllImportedFiles()
        await self.graphInitialized(importedFilesDir: importedFilesDir)
    }
    
    /// Called when GraphState is initialized to build library data and then run first calc.
    func graphInitialized(importedFilesDir: StitchDocumentSubdirectoryFiles,
                          graphMutation: (@Sendable @MainActor () -> ())? = nil) async {
        let migratedPublishedComponents = importedFilesDir.publishedComponentUrls.compactMap { componentUrl in
            do {
                return try StitchComponent.migrateEncodedComponent(from: componentUrl)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
                return nil
            }
        }
        
        // Start graph once library is built
        await MainActor.run { [weak self] in
            guard let encoder = self else {
                return
            }
            
            // Mutates graph before computation is called on importedFilesDirectoryReceived caller below
            graphMutation?()
            
            encoder.delegate?.importedFilesDirectoryReceived(mediaFiles: importedFilesDir.importedMediaUrls,
                                                             publishedComponents: migratedPublishedComponents)
        }
    }
}
