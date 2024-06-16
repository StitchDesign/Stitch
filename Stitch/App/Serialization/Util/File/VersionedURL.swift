//
//  VersionedURL.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias VersionedURLDict = [Int: URL]

extension VersionedURLDict {
    /// 2 goals here:
    /// 1. Get the newest versioned data document, and
    /// 2. Delete the older documents.
    func getAndCleanupVersions() throws -> URL? {
        // Sort by older documents
        var sortedDocuments = self
            .sorted { lhs, rhs in
                lhs.key < rhs.key
            }
            .map { $0.value }
        
        // Newest document is last in last
        let newestDocumentURL = sortedDocuments.popLast()
        
        // Remove remaining documents
        for oldDocumentURL in sortedDocuments {
            try FileManager.default.removeItem(at: oldDocumentURL)
        }
        
        return newestDocumentURL
    }
}

extension URL {
    /// Uses `FileManager` to enumerate through files at this URL to find the versioned data JSON.
    func getVersionedDataUrls() -> VersionedURLDict {
        do {
            let items = try FileManager.default.contentsOfDirectory(at: self,
                                                                    includingPropertiesForKeys: nil)
            
            // Search for file matching "data.v(n).json"
            return items.reduce(into: [:]) { result, file in
                guard file.filename.hasPrefix("\(StitchDocument.graphDataFileName).v") else {
                    return
                }
                
                let fileSplit = file.filename.split(separator: ".")
                guard let versionNumString = fileSplit[safe: 1]?.dropFirst(),
                      let versionNum = Int(versionNumString) else {
                    return
                }
                
                result.updateValue(file, forKey: versionNum)
            }
        } catch {
            log("URL.getVersionedDataUrl error: \(error.localizedDescription)")
            return [:]
        }
    }
}
