//
//  SoundKitNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/1/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// func soundKitNode(id: NodeId,
//                  position: CGPoint = .zero,
//                  zIndex: Double = 0) -> PatchNode {
//
//    let inputs = toInputs(
//        id: id,
//        values:
//            ("Sound", [.asyncMedia(positivePingStitchAudio(nodeId: id, loopIndex: 0))]), // 0
//        ("Play", [pulseDefaultFalse]), // 1
//        ("Volume", [.number(0.3)]) // 2 ... not used right now
//    )
//
//    // FAKE, HAS NO OUTPUTS!
//    let outputs = fakeOutputs(id: id, offset: inputs.count)
//
//    return PatchNode(position: position,
//                     previousPosition: position,
//                     zIndex: zIndex,
//                     id: id,
//                     patchName: .soundKit,
//                     inputs: inputs,
//                     outputs: outputs)
// }
//
//// TODO: Update to use preset sounds
//// TODO: inputs cannot take a loop?
// func soundKitEval(node: PatchNode,
//                  graphStep: GraphStepState,
//                  computedGraphState: ComputedGraphState) -> ImpureEvalResult {
//
//    let inputsValues = node.inputs
//    let graphTime: TimeInterval = graphStep.graphTime
//
//    let manualPulses = computedGraphState.manuallyPulsedInputs
//    let playPulsed = PulsedPort(input: .init(portId: 0, nodeId: node.id), manualPulses)
//
//    log("soundKitEval called")
//
//    //    let soundInput: PortValues = inputsValues[0]
//    let pulseInput: PortValues = inputsValues[1]
//
//    // sound loops are coerced to a single sound
//    //    let sound: SoundName = soundInput.first { (value: PortValue) -> Bool in
//    //        value.getSound != nil
//    //    }!.getSound!
//    //
//    //    let sound: StitchAudio = soundInput.first { (value: PortValue) -> Bool in
//    //        value.getSound != nil
//    //    }!.getSound!
//
//    let pulsed: Bool = pulseInput.contains { (value: PortValue) -> Bool in
//        if let pulsedAt = value.getPulse {
//            log("soundKitEval: had a pulse: pulsedAt: \(pulsedAt)")
//            return pulsedAt.shouldPulse(graphTime)
//        }
//        return false
//    }
//
//    var pulses = PulsedPortsSet()
//    if pulsed || playPulsed.wasManuallyPulsed {
//        log("soundKitEval: pulsed, but will NOT play sound")
//        pulses.insert(playPulsed.coordinate)
//
//        // doesn't work anymore, since StitchAudio is a URL, but
//        //        fatalError("name and url-based sounds are not compatible")
//
//        // TODO: just grab the file name
//        //        sound.url.absoluteString
//
//        //        playSound(sound: sound, type: ".mp3")
//    }
//
//    return ImpureEvalResult(outputsValues: node.outputs,
//                            pulsedIndices: pulses)
// }
