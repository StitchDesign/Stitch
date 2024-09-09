//
//  StitchDocumentURLUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation
import StitchSchemaKit

extension URL {
    static let componentsDirPath = "Components"
    
    func appendingStitchProjectDataPath(_ documentId: UUID) -> URL {
        self.appendingPathComponent(StitchDocument.getUniqueInternalDirectoryName(from: documentId),
                                    conformingTo: .stitchProjectData)
    }
    
//    func appendingStitchProjectDataPath(_ projectId: ProjectId) -> URL {
//        self.appendingPathComponent(StitchDocument.getFileName(projectId: projectId),
//                                    conformingTo: .stitchProjectData)
//    }

    func appendingStitchMediaPath() -> URL {
        self.appendingPathComponent(STITCH_IMPORTED_FILES_DIR)
    }

    func appendingDataJsonPath() -> URL {
        self.appendingPathComponent(StitchClipboardContent.dataJsonName,
                                    conformingTo: .json)
    }

    /// Creates path for StitchDocument contents, specifiy the version number in the URL.
    func appendingVersionedSchemaPath(_ version: StitchSchemaVersion = StitchSchemaVersion.getNewestVersion()) -> URL {
        self.appendingPathComponent(StitchDocument.graphDataFileName)
            .appendingPathExtension(StitchDocument.createDataFileExtension(version: version))
    }
}
