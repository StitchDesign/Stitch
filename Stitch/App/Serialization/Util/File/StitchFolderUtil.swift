//
//  StitchFolder.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/30/21.
//

import Foundation
import StitchSchemaKit
import Tagged
import SwiftUI

let STITCH_EXTENSION_RAW = "stitch"
let STITCH_PROJECT_EXTENSION_RAW = "stitchproject"
let STITCH_JSON_EXTENSION = "stitchjson"

let STITCH_IMPORTED_FILES_DIR = "ImportedFiles"
let STITCH_TEMPORARY_MEDIA_DIR = "TemporaryMedia"

let STITCH_PROJECT_THUMBNAIL_PATH_COMPONENT = "projectThumbnail.png"

let STITCH_SCHEMA_NAME = "schema"
let STITCH_SCHEMA_EXTENSION = "json"

// Could be for iCloud Documents or local Documents
struct DocumentsURL: Equatable, Codable {
    let url: URL
    typealias Id = Tagged<DocumentsURL, URL>
}

extension StitchDocumentIdentifiable {
    func getImportedFilesURL(forRecentlyDeleted: Bool = false) -> URL {
        self.getUrl(forRecentlyDeleted: forRecentlyDeleted)
            .appendingStitchMediaPath()
    }
    
    func getProjectThumbnailURL() -> URL {
        self.rootUrl.appendProjectThumbnailPath()
    }
    
    func getProjectThumbnailImage() -> UIImage? {
        let thumbnail: URL = self.getProjectThumbnailURL()
                        
        let data: Data? = try? Data.init(contentsOf: thumbnail)
        let thumbnailImage: UIImage? = data.flatMap {
            UIImage(data: $0)
        }
        
        return thumbnailImage
    }
}

extension URL {
    func appendProjectThumbnailPath() -> URL {
        self.appendingPathComponent(STITCH_PROJECT_THUMBNAIL_PATH_COMPONENT)
    }
}

extension StitchDocument {
    static let temporaryMediaURL: URL = StitchFileManager.tempDir.appendingPathComponent("TemporaryMedia")

    static let recentlyDeletedURL: URL = StitchFileManager.tempDir.appendingPathComponent("RecentlyDeleted")
}
