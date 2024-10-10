//
//  StitchFolder.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/30/21.
//

import Foundation
import StitchSchemaKit
import Tagged
import SwiftUI

let STITCH_IMPORTED_FILES_DIR = "ImportedFiles"
let STITCH_TEMPORARY_MEDIA_DIR = "TemporaryMedia"

let STITCH_PROJECT_THUMBNAIL_PATH_COMPONENT = "projectThumbnail.png"

let STITCH_SCHEMA_NAME = "schema"
let STITCH_SCHEMA_EXTENSION = "json"

extension DocumentEncodable {
    var componentsDirUrl: URL {
        self.rootUrl.appending(component: URL.componentsDirPath)
    }
    
    func getImportedFilesURL(forRecentlyDeleted: Bool = false) -> URL {
        self.getUrl(forRecentlyDeleted: forRecentlyDeleted)
            .appendingStitchMediaPath()
    }
    
    static func getProjectThumbnailURL(rootUrl: URL) -> URL {
        rootUrl.appendProjectThumbnailPath()
    }
    
    static func getProjectThumbnailImage(rootUrl: URL) -> UIImage? {
        let thumbnail: URL = Self.getProjectThumbnailURL(rootUrl: rootUrl)
                        
        let data: Data? = try? Data.init(contentsOf: thumbnail)
        let thumbnailImage: UIImage? = data.flatMap {
            UIImage(data: $0)
        }
        
        return thumbnailImage
    }
    
    func getUrl(forRecentlyDeleted: Bool = false) -> URL {
        if forRecentlyDeleted {
            return self.recentlyDeletedUrl
        }
        return self.rootUrl
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
