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

extension SoundImportNode {
    @MainActor
    static func soundImportEvalOp(media: GraphMediaValue,
                                  values: PortValues,
                                  defaultOutputs: PortValues,
                                  graphTime: TimeInterval) -> PortValues {
        guard let soundPlayer = media.mediaObject.soundFilePlayer else {
            return defaultOutputs
        }
        
        let delegate = soundPlayer.delegate
        let jumpTime = values[safe: 1]?.getNumber ?? .zero
        let jumpPulse = values[safe: 2]?.getPulse ?? .zero
        let playing: Bool = values[safe: 3]?.getBool ?? true
        let isLooped: Bool = values[safe: 4]?.getBool ?? true
        let playRate: Double = values[safe: 5]?.getNumber ?? 1
        
        // Get previously saved playback time in case video is paused
        var currentPlaybackTime = values[safe: 9]?.getNumber ?? .zero
        
        if playing {
            currentPlaybackTime = delegate.getCurrentPlaybackTime()
        }
        
        var values: PortValues = [
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
}

@MainActor
func soundImportEval(node: PatchNode) -> EvalResult {
    let graphTime = node.graphDelegate?.graphStepState.graphTime ?? .zero
    let defaultOutputs = node.defaultOutputs
    
    // MARK: sound player eval called each frame so we want to be selective about creating new sound player objects
    let results: [MediaEvalOpResult] = node.loopedEval(MediaEvalOpObserver.self) { values, mediaObserver, loopIndex in
        let asyncMedia = values.first?.asyncMedia
        
        let currentMedia = node.getInputMediaValue(portIndex: 0,
                                                   loopIndex: loopIndex)
                
        let didMediaChange = asyncMedia?.id != currentMedia?.id
        let isLoadingNewMedia = mediaObserver.currentLoadingMediaId != nil
        let willLoadNewMedia = didMediaChange && !isLoadingNewMedia
        
        guard !willLoadNewMedia else {
            mediaObserver.currentLoadingMediaId = asyncMedia?.id
            
            // Create new unique copy
            return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                                  values: values,
                                                  node: node) { [weak mediaObserver] () -> MediaEvalOpResult in
                guard let media = await mediaObserver?.getUniqueMedia(inputMediaValue: asyncMedia,
                                                                      inputPortIndex: 0,
                                                                      loopIndex: loopIndex) else {
                    return MediaEvalOpResult(from: defaultOutputs)
                }
                
                let outputs = await SoundImportNode.soundImportEvalOp(media: media,
                                                                      values: values,
                                                                      defaultOutputs: defaultOutputs,
                                                                      graphTime: graphTime)
                
                // Disable loading state
                await MainActor.run {
                    mediaObserver?.currentLoadingMediaId = nil
                }
                
                return .init(values: outputs,
                             media: media)
            }
        }
        
        guard let currentMedia = currentMedia else {
            return .init(from: defaultOutputs)
        }

        let outputs = SoundImportNode.soundImportEvalOp(media: currentMedia,
                                                        values: values,
                                                        defaultOutputs: defaultOutputs,
                                                        graphTime: graphTime)
        return MediaEvalOpResult(values: outputs,
                                 media: currentMedia)
    }
    
    var finalResult = results.createPureEvalResult(node: node)
    
    // MARK: frequencies logic saved for end due to loop of values
    
    if let soundPlayer = node.getComputedMedia(loopIndex: 0)?.soundFilePlayer {
        // Frequencies logic
        let frequencyAmplitudes = soundPlayer.delegate.frequencyAmplitudes
        
        let frequencyAmplitudesValues = frequencyAmplitudes.map { PortValue.number($0) }
        
        if finalResult.outputsValues[safe: 5] != nil {
            finalResult.outputsValues[5] = frequencyAmplitudesValues
        } else {
            finalResult.outputsValues.append(frequencyAmplitudesValues)
        }
    }
    
    return finalResult
}
