//
//  MediaUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AVFoundation

/// Helper for sample range file creation. Creates a boundary on some media asset (either video or audio).
func createMediaComposition(on composition: AVMutableComposition,
                            mediaType: AVMediaType,
                            mediaAsset: AVAsset,
                            startTime: TimeInterval,
                            duration: TimeInterval) {
    let compositionMediaTrack = composition.addMutableTrack(withMediaType: mediaType,
                                                            preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))

    mediaAsset.tracks(withMediaType: mediaType).forEach { sourceMediaTrack in
        do {
            try compositionMediaTrack?
                .insertTimeRange(CMTimeRangeMake(start: startTime.cmTime,
                                                 duration: duration.cmTime),
                                 of: sourceMediaTrack, at: .zero)
        } catch {
            log("createMediaComposition error inserting time range: \(error.localizedDescription)")
        }
    }

    // Video track needs to rotate the video, which otherwise appears upside down
    if mediaType == .video,
       let videoTrack = mediaAsset.tracks.first {
        var transforms = videoTrack.preferredTransform
        transforms = transforms.concatenating(CGAffineTransform(translationX: 0, y: 720))
        compositionMediaTrack?.preferredTransform = transforms
    }
}

extension MediaObjectId: Identifiable {
    public var id: String {
        self.uuidString
    }
}

typealias MediaIdSet = Set<MediaObjectId>
