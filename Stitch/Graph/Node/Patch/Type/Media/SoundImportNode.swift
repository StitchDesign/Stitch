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
                ),
                .init(
                    label: "Volume Spectrum",
                    type: .number
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        SoundImportMediaEvalOpObserver()
    }
}

@Observable
final class SoundImportMediaEvalOpObserver: NodeEphemeralOutputPersistence, MediaEvalOpObservable {
    static let outputIndexToSave = 3
    
    @MainActor var previousValue: PortValue?
    @MainActor var currentLoadingMediaId: UUID?
    let mediaViewModel: MediaViewModel
    let mediaActor: MediaEvalOpCoordinator
    @MainActor weak var nodeDelegate: NodeViewModel?
    
    @MainActor init() {
        self.mediaViewModel = .init()
        self.mediaActor = .init()
    }
    
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.previousValue = nil
    }
}

extension SoundImportNode {
    @MainActor
    static func soundImportEvalOp(media: GraphMediaValue,
                                  observer: SoundImportMediaEvalOpObserver,
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
        var currentPlaybackTime = observer.previousValue?.getNumber ?? .zero
        
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
}

@MainActor
func soundImportEval(node: PatchNode) -> EvalResult {
    let graphTime = node.graphDelegate?.graphStepState.graphTime ?? .zero
    let defaultOutputs = node.defaultOutputs

    var evalResult = node.loopedEvalOutputsPersistence() { (values, mediaObserver, loopIndex) -> MediaEvalOpResult in
        
        mediaObserver.mediaEvalOpCoordinator(inputPortIndex: 0,
                                             values: values,
                                             loopIndex: loopIndex,
                                             defaultOutputs: defaultOutputs) { @Sendable media in
            SoundImportNode.soundImportEvalOp(media: media,
                                              observer: mediaObserver,
                                              values: values,
                                              defaultOutputs: defaultOutputs,
                                              graphTime: graphTime)
        }
    }
    
    // MARK: frequencies logic saved for end due to loop of values
    
    if let mediaId = node.getInputRowObserver(0)?.values.first?.asyncMedia?.id,
       let soundPlayer = node.getComputedMedia(loopIndex: 0,
                                               mediaId: mediaId)?.soundFilePlayer {
        // Frequencies logic
        let frequencyAmplitudes = soundPlayer.delegate.frequencyAmplitudes
        
        let frequencyAmplitudesValues = frequencyAmplitudes.map { PortValue.number($0) }
        
        if evalResult.outputsValues[safe: 5] != nil {
            evalResult.outputsValues[5] = frequencyAmplitudesValues
        } else {
            evalResult.outputsValues.append(frequencyAmplitudesValues)
        }
    }
    
    return evalResult
}
