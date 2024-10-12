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

let STITCH_PROJECT_THUMBNAIL_PATH_COMPONENT = "projectThumbnail.png"

let STITCH_SCHEMA_NAME = "schema"
let STITCH_SCHEMA_EXTENSION = "json"

extension DocumentEncodable {    
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
}

extension URL {
    func appendProjectThumbnailPath() -> URL {
        self.appendingPathComponent(STITCH_PROJECT_THUMBNAIL_PATH_COMPONENT)
    }
}

extension StitchFileManager {
    static let tempDocumentResources: URL = StitchFileManager.tempDir.appendingPathComponent("TempDocumentResources")

    static let recentlyDeletedURL: URL = StitchFileManager.tempDir.appendingPathComponent("RecentlyDeleted")
}
