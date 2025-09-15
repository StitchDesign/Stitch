//
//  SpeakerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AudioKit

struct SpeakerPatchNode: PatchNodeDefinition {
    static let patch = Patch.speaker

    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: "Sound",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Volume"
                )
            ],
            outputs: [
                // Speaker has no real outputs, so we create a disabled output
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }
}


@MainActor
func speakerEval(node: PatchNode) -> EvalResult {
    // MARK: media object is obtained by looking at upstream connected node's saved media objects. This system isn't perfect as not all nodes which can hold media use the MediaEvalOpObserver.
    let upstreamNode = node.inputsObservers.first?
        .upstreamOutputObserver?
        .nodeDelegate
    
    let _ = loopedEval(node: node) { values, loopIndex in
        guard let mediaId = values.first?.asyncMedia?.id,
              let mediaObject = upstreamNode?
            .getComputedMedia(loopIndex: loopIndex, mediaId: mediaId),
              let volume = values[safe: 1]?.getNumber,
              let speakerMedia = mediaObject.soundPlayable else {
            log("speakerEval error: no engine or soundinput found.")
            return
        }
        
        // TODO: player volume should be displayed from this speaker node
        speakerMedia.updateVolume(volume)
    }
    
    return EvalResult(outputsValues: [])
}
