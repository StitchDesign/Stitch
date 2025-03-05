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

@MainActor
func speakerNode(id: NodeId,
                 audio: AsyncMediaValue? = nil,
                 position: CGSize = .zero,
                 zIndex: Double = 0) -> PatchNode {
    let inputs = toInputs(
        id: id,
        values:
            ("Sound", [.asyncMedia(audio)]),
        ("Volume", [.number(1)])
    )

    // no outputs actually?
    let outputs = fakeOutputs(id: id, offset: inputs.count)

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .speaker,
        inputs: inputs,
        outputs: outputs)
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
