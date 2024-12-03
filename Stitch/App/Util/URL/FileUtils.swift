//
//  FileUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/22/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

typealias DirectoryContents = [URL]

let SUPPORTED_CONTENT_TYPES: [UTType] = [.plainText, .image, .video, .mp3, .movie, .audio, .item, .usdz, .usd]

typealias MediaImportCallback = ([URL]) -> Void

let MIC_RECORDING_FILE_EXT = "caf"

extension StitchFileManager {
    static func createTempURL(fileExt: String) -> URL {
        let temporaryDirectoryURL = Self.tempDir

        let outputFileURL = temporaryDirectoryURL
            .appendingPathComponent("\(UUID())").appendingPathExtension(fileExt)
        return outputFileURL
    }
}
