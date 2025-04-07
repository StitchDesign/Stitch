//
//  MicrophoneFeedNode.swift
//  Stitch
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

// needs to be impure, in order to be able to update state as well;
// we can create the AVAudioRecorder when we first add the node to the graph;
// but if eg the microphone is turned off, then we'll need to dispatch a side effect to change the state as well
@MainActor
func microphoneEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { (values, mediaObserver, _) -> MediaEvalOpResult in
        guard let isEnabled = values.first?.getBool,
              isEnabled else {
            mediaObserver.resetMedia()
            return MediaEvalOpResult(from: node.defaultOutputs)
        }
        
        // Skip if mic still loading
        guard mediaObserver.currentLoadingMediaId == nil else {
            return MediaEvalOpResult(from: node.defaultOutputs)
        }
           
        guard let currentMedia = mediaObserver.computedMedia,
              let mic = currentMedia.mediaObject.mic else {
            let newMic = StitchMic(isEnabled: isEnabled)
            let newSoundPlayer = StitchSoundPlayer(delegate: newMic, willPlay: true)
            
            mediaObserver.computedMedia = .init(computedMedia: .mic(newSoundPlayer))
            
            return MediaEvalOpResult(values: node.defaultOutputs,
                                     media: mediaObserver.computedMedia)
        }
        
        guard var previousVolume: Double = values[safe: 2]?.getNumber,
              var previousPeakVolume: Double = values[safe: 3]?.getNumber else {
            log("microphoneEval: issue finding inputs")
                return MediaEvalOpResult(from: node.defaultOutputs)
        }
        
        mic.isEnabled = isEnabled
        
        let volumeData = mic.delegate.retrieveVolumeData()
        let average = volumeData.0
        let peak = volumeData.1
        previousVolume = Double(average)
        previousPeakVolume = Double(peak)
        
        let outputs = [currentMedia.portValue,
                .number(previousVolume), // values[2], // volume, unchanged
                .number(previousPeakVolume)// values[3] // peak volume, unchanged
        ]
        
        return MediaEvalOpResult(values: outputs,
                                 media: currentMedia)
    }
}

