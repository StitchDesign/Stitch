//
//  SpeakerNode.swift
//  prototype
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
    let outputsValues = loopedEval(node: node) { values, loopIndex in
        guard let volume = values[safe: 1]?.getNumber,
              let speakerMedia = values.first?.asyncMedia?.mediaObject.soundFilePlayer else {
            log("speakerEval error: no engine or soundinput found.")
            return [PortValue.number(0)]
        }
        
        // TODO: player volume should be displayed from this speaker node
        speakerMedia.updateVolume(volume)
        return [PortValue.number(0)]
    }
        .remapOutputs()
    
    return EvalResult(outputsValues: outputsValues)
}
