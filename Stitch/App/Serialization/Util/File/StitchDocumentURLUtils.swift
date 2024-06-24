//
//  StitchDocumentURLUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation
import StitchSchemaKit

extension URL {
    func appendingStitchDocPath(_ document: StitchDocumentIdentifiable) -> URL {
        self.appendingPathComponent(document.uniqueInternalDirectoryName, conformingTo: .stitchDocument)
    }

    func appendingStitchProjectDataPath(_ document: StitchDocumentIdentifiable) -> URL {
        self.appendingPathComponent(document.uniqueInternalDirectoryName, conformingTo: .stitchProjectData)
    }

    func appendingStitchDocPath(_ projectId: ProjectId) -> URL {
        self.appendingPathComponent(StitchDocument.getFileName(projectId: projectId),
                                    conformingTo: .stitchDocument)
    }

    func appendingStitchMediaPath() -> URL {
        self.appendingPathComponent(STITCH_IMPORTED_FILES_DIR)
    }

    func appendingDataJsonPath() -> URL {
        self.appendingPathComponent(StitchComponent.dataJsonName,
                                    conformingTo: .json)
    }

    /// Creates path for StitchDocument contents, specifiy the version number in the URL.
    func appendingVersionedSchemaPath(_ version: StitchSchemaVersion = StitchSchemaVersion.getNewestVersion()) -> URL {
        self.appendingPathComponent(StitchDocument.graphDataFileName)
            .appendingPathExtension(StitchDocument.createDataFileExtension(version: version))
    }
}
