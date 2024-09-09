//
//  StitchFileManangerEvents.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/21/22.
//

import Foundation
import StitchSchemaKit

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
    func getDecodedFiles() async -> GraphDecodedFiles? {
        let importedFilesDir = self.readAllImportedFiles()
        return await self.getDecodedFiles(importedFilesDir: importedFilesDir)
    }
    
    /// Called when GraphState is initialized to build library data and then run first calc.
    func getDecodedFiles(importedFilesDir: StitchDocumentDirectory,
                         graphMutation: (@Sendable @MainActor () -> ())? = nil) async -> GraphDecodedFiles? {
        let migratedComponents = importedFilesDir.componentDirs.compactMap { componentUrl -> StitchComponentData? in
            do {
                guard let draft = try StitchComponent.migrateEncodedComponent(from: componentUrl.appendingComponentDraftPath()),
                      let published = try StitchComponent.migrateEncodedComponent(from: componentUrl.appendingComponentPublishedPath()) else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                return StitchComponentData(draft: draft,
                                           published: published)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
                return nil
            }
        }
        
        return .init(mediaFiles: importedFilesDir.importedMediaUrls,
                     components: migratedComponents)
    }
}
