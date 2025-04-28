//
//  MediaKey.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/22/21.
//

import Foundation
import StitchSchemaKit
import RealityKit
import UIKit
import Vision

extension MediaKey {
    var description: String {
        filename + "." + fileExtension
    }
    
    func getMediaType() -> SupportedMediaFormat? {
        SupportedMediaFormat.findType(by: self.fileExtension)
    }
}

extension DataType where Value == MediaKey {
    var mediaKey: MediaKey? {
        switch self {
        case .source(let mediaKey):
            return mediaKey
        default:
            return nil
        }
    }
}

extension PortValuesList {
    func findImportedMediaKeys() -> [MediaKey] {
        self.flatMap { $0 }
            .findImportedMediaKeys()
    }
}

extension PortValues {
    func findImportedMediaKeys() -> [MediaKey] {
        let defaultMediaKeys = MediaLibrary.getAllDefaultMediaKeys().toSet
        return self.compactMap { $0.asyncMedia }
            // Exclude default media and any non-imported media
            .filter { asyncMedia in
                switch asyncMedia.dataType {
                case .computed:
                    return false
                case .source(let mediaKey):
                    return !defaultMediaKeys.contains(mediaKey)
                }
            }
            .compactMap { $0.mediaKey }
    }
}
