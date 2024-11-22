//
//  URLExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AVKit

extension URL {
    var mediaKey: MediaKey {
        MediaKey(self)
    }

    func getMediaType() -> SupportedMediaFormat {
        SupportedMediaFormat.findType(by: self.pathExtension)
    }

    func supports(mediaFormat: SupportedMediaFormat) -> Bool {
        self.getMediaType() == mediaFormat
    }

    func trimMedia(startTime: TimeInterval,
                   endTime: TimeInterval) async -> MediaObjectResult {

        guard let mediaType = self.getMediaType().avMediaType else {
            return .failure(.mediaFileUnsupported(self.pathExtension))
        }

        let _ = self.startAccessingSecurityScopedResource()

        let duration = endTime - startTime
        let outUrl = StitchDocument.temporaryMediaURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(self.pathExtension)

        guard duration > 0 else {
            log("trimSound error: a negative duration was calculated.")
            return .failure(.trimMediaFileFailed)
        }

        let mediaAsset = AVAsset(url: self)
        let composition = AVMutableComposition()

        // Both video and audio types require an audio track, however only video creates a video track
        createMediaComposition(on: composition,
                               mediaType: .audio,
                               mediaAsset: mediaAsset,
                               startTime: startTime,
                               duration: duration)

        createMediaComposition(on: composition,
                               mediaType: .video,
                               mediaAsset: mediaAsset,
                               startTime: startTime,
                               duration: duration)

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            log("trimSound error: could not create exporter.")
            self.stopAccessingSecurityScopedResource()
            return .failure(.trimMediaFileFailed)
        }
        exporter.outputURL = outUrl

        switch mediaType {
        case .audio:
            exporter.outputFileType = AVFileType.m4a
        case .video:
            exporter.outputFileType = AVFileType.mov
        default:
            break
        }

        await exporter.export()

        self.stopAccessingSecurityScopedResource()

        // Convert URL into decoded media object
        return await outUrl.createMediaObject(nodeId: nil)
    }

    func getLastModifiedDate(fileManager: FileManager) -> Date {
        guard let attr = try? fileManager.attributesOfItem(atPath: self.path),
              let date = attr[FileAttributeKey.modificationDate] as? Date else {

            // log("getLastModifiedDate: had no attr; returning date \(Date.now) for url \(self)")
            //            return Date.distantPast

            /*
             HACK: when we are unable to read the modified-date xattr on the loading-url, we can default to Date.now so that the project is sorted to the top of the projects-homescreen-grid and gets loaded.

             (It's unclear why some urls do not have xattr. The same project will have the xattr on iPad but not iPhone, etc.)
             */
            return Date.now
        }
        // log("getLastModifiedDate: had attr; returning date \(date) for url \(self)")
        return date
    }
}
