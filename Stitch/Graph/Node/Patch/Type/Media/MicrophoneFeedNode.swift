//
//  MicrophoneFeedNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 6/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct MicrophoneNode: PatchNodeDefinition {
    static let patch = Patch.microphone

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.bool(false)],
                    label: "Enabled"
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
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

/// Creates mic and assigns to observer.
@MainActor func createMic(isEnabled: Bool,
               observer: MediaEvalOpObserver) -> StitchSoundPlayer<StitchMic> {
    let newMic = StitchMic(isEnabled: isEnabled)
    let newSoundPlayer = StitchSoundPlayer(delegate: newMic, willPlay: true)
    observer.currentMedia = .init(computedMedia: .mic(newSoundPlayer))
    return newSoundPlayer
}

// needs to be impure, in order to be able to update state as well;
// we can create the AVAudioRecorder when we first add the node to the graph;
// but if eg the microphone is turned off, then we'll need to dispatch a side effect to change the state as well
@MainActor
func microphoneEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, mediaObserver, _ in
        guard let isEnabled = values.first?.getBool,
              isEnabled else {
            mediaObserver.resetMedia()
            return node.defaultOutputs
        }
           
        let mic: StitchSoundPlayer<StitchMic>
        if let currentMic = mediaObserver.currentMedia?.mediaObject.mic {
            mic = currentMic
        } else {
            mic = createMic(isEnabled: isEnabled,
                            observer: mediaObserver)
        }
        
        guard var previousVolume: Double = values[safe: 2]?.getNumber,
              var previousPeakVolume: Double = values[safe: 3]?.getNumber else {
            log("microphoneEval: issue finding inputs")
            return node.defaultOutputs
        }
        
        mic.isEnabled = isEnabled
        
        let volumeData = mic.delegate.retrieveVolumeData()
        let average = volumeData.0
        let peak = volumeData.1
        previousVolume = Double(average)
        previousPeakVolume = Double(peak)
        
        let mediaValue = GraphMediaValue(computedMedia: .mic(mic))
        return [mediaValue.portValue,
                .number(previousVolume), // values[2], // volume, unchanged
                .number(previousPeakVolume)// values[3] // peak volume, unchanged
        ]
    }
}

