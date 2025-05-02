//
//  StitchClipboardContent.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/3/24.
//

import SwiftUI
import UniformTypeIdentifiers
import StitchSchemaKit

extension StitchComponent: StitchDocumentEncodable {
    static let subfolders: [StitchEncodableSubfolder] = StitchEncodableSubfolder.allCases
}

struct StitchClipboardContent: StitchComponentable, StitchDocumentEncodable {
    static let unzippedFileType = UTType.stitchClipboard
    static let dataJsonName = StitchDocument.graphDataFileName
    static let subfolders: [StitchEncodableSubfolder] = StitchEncodableSubfolder.allCases
    
    var graphEntity: GraphEntity
}

extension StitchClipboardContent {
    static func getDocument(from url: URL) throws -> StitchClipboardContent? {
        let data = try Data(contentsOf: url)
        let decoder = getStitchDecoder()
        return try decoder.decode(StitchClipboardContent.self, from: data)
    }
    
    init() {
        self.init(graphEntity: .createEmpty())
    }
    var rootUrl: URL {
        Self.rootUrl
    }
    
    static var rootUrl: URL {
        StitchFileManager.tempDir
            .appendingPathComponent("ClipboardData")
            .appendingPathComponent("copied-data",
                                    conformingTo: Self.unzippedFileType)
    }
    
    var dataJsonUrl: URL {
        self.rootUrl
            .appendingPathComponent(StitchClipboardContent.dataJsonName,
                                    conformingTo: .json)
    }
    
    func getEncodingUrl(documentRootUrl: URL) -> URL {
        // Ignore param, always using temp directory
        self.rootUrl
    }
}
