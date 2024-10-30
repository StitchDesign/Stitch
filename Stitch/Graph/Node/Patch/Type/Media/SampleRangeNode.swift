//
//  SampleRangeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SampleRangeNode: PatchNodeDefinition {
    static let patch = Patch.sampleRange

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: "Value"
                ),
                .init(
                    label: "Start",
                    staticType: .pulse
                ),
                .init(
                    label: "End",
                    staticType: .pulse
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .media
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

@MainActor
func sampleRangeEval(node: PatchNode,
                     graphState: GraphDelegate) -> ImpureEvalResult {
    // MARK: Currently disabled
    return .init(outputsValues: node.defaultOutputsList)
    
//    let manualPulses: PulsedPortsSet = computedGraphState.manuallyPulsedInputs
//    let startPulse = PulsedPort(input: InputCoordinate(portId: 1,
//                                                       nodeId: node.id), manualPulses)
//    let endPulse = PulsedPort(input: InputCoordinate(portId: 2,
//                                                     nodeId: node.id), manualPulses)
//
//    return node.loopedEval(ComputedNodeState.self) { values, computedState, index in
//        guard let inputMedia = values.first?.asyncMedia,
//              let mediaObject = mediaManager.mediaDict.get(inputMedia.id) else {
//            return .init(outputs: DEFAULT_SAMPLE_RANGE_OUTPUTS)
//        }
//
//        var effects = SideEffects()
//        let graphTime = graphStepState.graphTime
//        var pulses = PulsedPortsSet()
//        let mediaId = inputMedia.id
//
//        var sampleRangeState = computedState.sampleRangeState ?? SampleRangeComputedState()
//        let currentMediaStatus = computedState.loadingStatus
//
//        // We must have these inputs as pulses; hence force-unwrap.
//        let startPulseTime: TimeInterval = values[1].getPulse!
//        let endPulseTime: TimeInterval = values[2].getPulse!
//
//        let hadStartPulse = startPulse.wasManuallyPulsed || startPulseTime.shouldPulse(graphTime)
//        let hadEndPulse = endPulse.wasManuallyPulsed || endPulseTime.shouldPulse(graphTime)
//
//        // Always add start/end pulses to `pulses`; then attempt media logic handling
//        if hadStartPulse {
//            pulses.insert(startPulse.coordinate)
//        }
//        if hadEndPulse {
//            pulses.insert(endPulse.coordinate)
//        }
//
//        if hadStartPulse {
//            // Teardown if previous media used
//            if let mediaIdToTeardown = currentMediaStatus?.id {
//                effects.append({ MediaPlayerTeardown(mediaId: mediaIdToTeardown) })
//            }
//
//            // Reset sample range value
//            sampleRangeState.mediaId = nil
//
//            // If mic, we need to create a new instance
//            let effects = effects
//            if mediaObject.mic.isDefined {
//                return asyncMediaComputedCopyOp(node: node,
//                                                mediaId: inputMedia.id.change(onNodeId: node.id, loopIndex: index),
//                                                values: values,
//                                                loopIndex: index,
//                                                inputMediaObject: mediaObject,
//                                                prevOutputs: .byIndex(sampleRangeState.createOutputs()),
//                                                mediaManager: mediaManager) { _, mediaId, mediaObject, _ in
//                    guard let micPlayer = mediaObject.mic else {
//                        return .init(outputs: DEFAULT_SAMPLE_RANGE_OUTPUTS)
//                    }
//
//                    // Start recording
//                    micPlayer.isEnabled = true
//
//                    return .init(outputs: [.asyncMedia(AsyncMediaValue(id: mediaId, dataType: .computed))],
//                                 mediaId: MediaIdLoadingStatus(id: mediaId, loadingStatus: .loaded),
//                                 effects: effects)
//                }
//            } else {
//                sampleRangeState.start = mediaObject.currentPlaybackTime
//            }
//        }
//
//        let _sampleRangeState = sampleRangeState
//
//        if hadEndPulse {
//            if let currentMediaId = currentMediaStatus?.id {
//                // Teardown current media if it exists
//                effects.append({ MediaPlayerTeardown(mediaId: currentMediaId) })
//
//                // Stop recording for mic and create sound player from range
//                // We use a different mic from the input instance
//                if let recordingMic = mediaManager.mediaDict.get(currentMediaId)?.mic,
//                   let recordingURL = recordingMic.delegate.url {
//                    recordingMic.isEnabled = false
//
//                    return asyncMediaEvalOp(node: node,
//                                            mediaManager: mediaManager,
//                                            loopIndex: index,
//                                            inputMediaKeypath: \.mediaDict[currentMediaId],
//                                            defaultOutputValues: .byIndex(DEFAULT_SAMPLE_RANGE_OUTPUTS)) { mediaId, _ in
//                        switch await recordingURL.createMediaObject(id: mediaId) {
//                        case .success(let mediaObject):
//                            var newSampleRangeState = _sampleRangeState
//                            newSampleRangeState.mediaId = mediaId
//                            return .init(outputs: [.asyncMedia(AsyncMediaValue(id: mediaId,
//                                                                               dataType: .computed))],
//                                         mediaObject: mediaObject,
//                                         sampleRangeState: newSampleRangeState)
//                        case .failure(let error):
//                            log("sample range: failed to make sound player from mic recording URL with error: \(error)")
//                            return .init(outputs: DEFAULT_SAMPLE_RANGE_OUTPUTS)
//                        }
//                    }
//                }
//            }
//
//            // Initial block is for sound file and video file input sources
//            // (when currentPlaybackTime is defined)
//            else if let currentPlaybackTime = mediaObject.currentPlaybackTime {
//                guard let rangeStartTime = sampleRangeState.start,
//                      currentPlaybackTime > rangeStartTime,
//                      let sourceURL = mediaObject.url else {
//
//                    // Reset range time if invalid
//                    log("sampleRangeResult: invalid sample range.")
//                    return .init(outputs: DEFAULT_SAMPLE_RANGE_OUTPUTS,
//                                 effects: effects,
//                                 pulses: pulses,
//                                 sampleRangeState: SampleRangeComputedState())
//                }
//                log("sampleRangeResult: valid sample range.")
//                let effects = effects
//
//                return asyncMediaEvalOp(node: node,
//                                        mediaManager: mediaManager,
//                                        loopIndex: index,
//                                        inputMediaKeypath: \.mediaDict[mediaId],
//                                        defaultOutputValues: .byIndex(DEFAULT_SAMPLE_RANGE_OUTPUTS)) { newMediaId, _ in
//                    var newSampleRangeState = _sampleRangeState
//                    newSampleRangeState.mediaId = newMediaId
//                    switch await sourceURL.trimMedia(startTime: rangeStartTime,
//                                                     endTime: currentPlaybackTime) {
//                    case .success(let trimmedObject):
//                        // If video, make sure it'll play
//                        if let trimmedVideo = trimmedObject.video {
//                            trimmedVideo.play()
//                        }
//
//                        return .init(outputs: [.asyncMedia(AsyncMediaValue(id: newMediaId, dataType: .computed))],
//                                     mediaObject: trimmedObject,
//                                     effects: effects)
//                    case .failure(let error):
//                        log("Sample range failed with error: \(error)")
//                        return .init(outputs: DEFAULT_SAMPLE_RANGE_OUTPUTS,
//                                     effects: effects)
//                    }
//                }
//            }
//        }
//
//        return .init(outputs: sampleRangeState.createOutputs(),
//                     mediaId: currentMediaStatus,
//                     effects: effects,
//                     pulses: pulses,
//                     sampleRangeState: sampleRangeState)
//    }
//    .toImpureEvalResult(node: node, 
//                        mediaManager: mediaManager,
//                        defaultOutputs: DEFAULT_SAMPLE_RANGE_OUTPUTS)
}
