//
//  VideoImportNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AVFoundation

struct VideoImportNode: PatchNodeDefinition {
    static let patch = Patch.videoImport

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: ""
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Scrubbable"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Scrub Time"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Playing"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Looped"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .media
                ),
                .init(
                    label: "Volume",
                    type: .number
                ),
                .init(
                    label: "Peak Volume",
                    type: .number
                ),
                .init(
                    label: "Playback",
                    type: .number
                ),
                .init(
                    label: "Duration",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

extension VideoImportNode {
    @MainActor
    static func videoImportEvalOp(media: GraphMediaValue,
                                  values: PortValues,
                                  defaultOutputs: PortValues) -> PortValues {
        guard let videoPlayer = media.mediaObject.video else {
            return defaultOutputs
        }
        
        let scrubbable: Bool = values[safe: 1]?.getBool ?? false
        let scrubTime: Double = values[safe: VIDEO_INPUT_INDEX_SCRUBTIME]?.getNumber ?? .zero
        let playing: Bool = values[safe: 3]?.getBool ?? false
        let isLooped: Bool = values[safe: 4]?.getBool ?? false
        
        let previousVolume: Double = videoPlayer.volume
        let previousPeakVolume: Double = videoPlayer.peakVolume
        
        let playTime = videoPlayer.currentTime
        let duration = videoPlayer.duration
        
        let newMetadata = VideoMetadata(isScrubbing: scrubbable,
                                        scrubTime: scrubTime,
                                        playing: playing && !scrubbable,
                                        isLooped: isLooped)
        
        let willVideoMetadataChange = videoPlayer.metadata != newMetadata
        
        if willVideoMetadataChange {
            // Update player in media manager
            videoPlayer.metadata = newMetadata
        }
        
        return [
            media.portValue,
            .number(previousVolume),
            .number(previousPeakVolume),
            .number(playTime),
            .number(duration)
        ]
    }
}

// MESSAGE-BASED IMPLEMENTATION OF VIDEO PLAYING
// Saved for later harmonizing with scrubTime-seeking approach.
@MainActor
func videoImportEval(node: PatchNode) -> EvalResult {
    let defaultOutputs = node.defaultOutputs
    
    return node.loopedEval(MediaEvalOpObserver.self) { values, asyncObserver, loopIndex -> MediaEvalOpResult in
        asyncObserver.mediaEvalOpCoordinator(inputPortIndex: 0,
                                             values: values,
                                             loopIndex: loopIndex,
                                             defaultOutputs: defaultOutputs) { media -> PortValues in
            VideoImportNode.videoImportEvalOp(media: media,
                                              values: values,
                                              defaultOutputs: defaultOutputs)
        }
    }
}
