//
//  StitchFileManangerEvents.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/21/22.
//

import Foundation
import StitchSchemaKit

extension DocumentEncodable {
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
