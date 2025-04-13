//
//  StitchFileManangerEvents.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/21/22.
//

import Foundation
import StitchSchemaKit

extension DocumentEncodable {
    func deleteMediaFromNode(mediaKey: MediaKey) {
        switch self.getMediaURL(for: mediaKey) {
        case .success(let url):
            let _ = self.removeStitchMedia(at: url)

        case .failure(let error):
            // Silently report error
            log("deleteMediaFromNodeEffect error: could not find library substate with error: \(error)")
        }
    }

    /// Called when GraphState is initialized to build library data and then run first calc.
    func getDecodedFiles() -> GraphDecodedFiles? {
        do {
            let importedFilesDir = try self.readAllImportedFiles()
            return GraphDecodedFiles(importedFilesDir: importedFilesDir)
        } catch {
            fatalErrorIfDebug("DocumentEncodable.getDecodedFiles error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Called when GraphState is initialized to build library data and then run first calc.
    static func getDecodedFiles(rootUrl: URL) -> GraphDecodedFiles? {
        do {
            let importedFilesDir = try Self.readAllImportedFiles(rootUrl: rootUrl)
            return GraphDecodedFiles(importedFilesDir: importedFilesDir)
        } catch {
            fatalErrorIfDebug("DocumentEncodable.getDecodedFiles error: \(error.localizedDescription)")
            return nil
        }
    }
}

extension GraphDecodedFiles {
    init?(importedFilesDir: StitchDocumentDirectory,
          graphMutation: (@Sendable @MainActor () -> ())? = nil) {
        let migratedComponents = importedFilesDir.componentDirs.compactMap { componentUrl -> StitchComponent? in
            do {
                guard let component = try StitchComponent.migrateEncodedComponent(from: componentUrl) else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                return component
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
                return nil
            }
        }
        
        self.init(mediaFiles: importedFilesDir.importedMediaUrls,
                  components: migratedComponents)
    }
}
