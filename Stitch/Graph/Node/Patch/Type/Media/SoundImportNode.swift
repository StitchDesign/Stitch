//
//  SoundImportNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/21.
//

import AudioKit
import Foundation
import SwiftUI
import StitchSchemaKit

let defaultAudioPlayRate = 1.0

struct SoundImportNode: PatchNodeDefinition {
    static let patch = Patch.soundImport
    static let defaultFrequencyAmplitudes: [Double] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Time"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Playing"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Looped"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Play Rate"
                )
            ],
            outputs: [
                .init(
                    label: "Sound",
                    type: .media
                ),
                .init(
                    label: "Overall Volume",
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
                ),
                .init(
                    label: "Volume Spectrum",
                    type: .number
                )
            ]
        )
    }
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func soundImportEval(node: PatchNode) -> EvalResult {
    let graphTime = node.graphDelegate?.graphStepState.graphTime ?? .zero
    var soundPlayer: StitchSoundPlayer<StitchSoundFilePlayer>?
    
    var result: EvalResult = node.loopedEval(MediaEvalOpObserver.self) { values, mediaObserver, loopIndex in
        guard let media = mediaObserver.getUniqueMedia(from: values.first,
                                                       loopIndex: loopIndex) else {
            return node.defaultOutputs
        }
        soundPlayer = media.mediaObject.soundFilePlayer
        
        guard let soundPlayer = soundPlayer else {
            return node.defaultOutputs
        }
        
        let delegate = soundPlayer.delegate
        let jumpTime = values[safe: 1]?.getNumber ?? .zero
        let jumpPulse = values[safe: 2]?.getPulse ?? .zero
        let playing: Bool = values[safe: 3]?.getBool ?? true
        let isLooped: Bool = values[safe: 4]?.getBool ?? true
        let playRate: Double = values[safe: 5]?.getNumber ?? 1
        
        // Get previously saved playback time in case video is paused
        var currentPlaybackTime = values[9].getNumber ?? .zero

        if playing {
            currentPlaybackTime = delegate.getCurrentPlaybackTime()
        }

        let values: PortValues = [
            media.portValue,
            .number(delegate.volume),
            .number(delegate.peakVolume),
            .number(currentPlaybackTime),
            .number(delegate.duration),
            //Fake value for output; will override below...
            .number(0)
        ]
        
        
        // Update player in media manager
        soundPlayer.isEnabled = playing

        delegate.isLooping = isLooped
        delegate.rate = AUValue(playRate)

        // Seek player if jump pulse triggered
        if graphTime == jumpPulse {
            delegate.setJumpTime(jumpTime)
        }
        
        return values
    }
    
    var frequencyAmplitudes: [Double] = []
    if let soundPlayer = soundPlayer {
        frequencyAmplitudes = soundPlayer.delegate.frequencyAmplitudes
    } else {
        frequencyAmplitudes = SoundImportNode.defaultFrequencyAmplitudes
    }
    
    let frequencyAmplitudesValues = frequencyAmplitudes.map { PortValue.number($0) }
    
    if result.outputsValues[safe: 5] != nil {
        result.outputsValues[5] = frequencyAmplitudesValues
    } else {
        result.outputsValues.append(frequencyAmplitudesValues)
    }
    
    return result
    
}
