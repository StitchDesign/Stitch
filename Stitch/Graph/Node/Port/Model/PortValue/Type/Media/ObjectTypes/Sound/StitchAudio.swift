//
//  StitchAudio.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/21.
//

import AudioKit
import AVKit
import Combine
import Foundation
import StitchSchemaKit

final class StitchSoundPlayer<Player: StitchSoundPlayerDelegate>: Sendable {
    let delegate: Player

    @MainActor var isEnabled: Bool {
        didSet(oldValue) {
            if oldValue != isEnabled {
                if isEnabled && !isRunning {
                    self.start()
                } else {
                    self.pause()
                }
            }
        }
    }

    @MainActor
    init(delegate: Player, willPlay: Bool = true) {
        // Should be defined or else player could have problems (see: mic)
        let isOutputDefined = delegate.engine.output != nil
        
        self.delegate = delegate
        self.isEnabled = willPlay

        // isEnabled publisher won't play from init
        if willPlay && isOutputDefined {
            self.start()
        }

        self.updateVolume(.zero)
    }

    @MainActor
    var engine: AudioEngine {
        self.delegate.engine
    }

    @MainActor
    private var isRunning: Bool {
        self.delegate.isRunning
    }

    /// Manages playing of sound player to ensure delegate player starts after engine.
    @MainActor
    private func start() {
        try? self.engine.start()

        let isRunning = self.delegate.isRunning
        if !isRunning {
            self.delegate.play()
        }
    }

    @MainActor
    private func pause() {
        self.engine.stop()
        self.delegate.pause()
    }

    @MainActor
    private func stop() {
        self.engine.stop()
        self.delegate.stop()
    }

    @MainActor
    func updateVolume(_ volume: Double) {
        self.engine.mainMixerNode?.volume = AUValue(volume)
    }

    // TODO: will revisit if this delay approach is necessary
    //    private func createAudioKitNode(node: AudioKit.Node) -> Delay {
    //        if delay > 2 {
    // how many times to add a delay node with max delay
    //            let f: Double = (delay / 2).rounded(.down)
    //            let delays = Int(f)

    // add the final
    //            let f2 = delay.remainder(dividingBy: 2)

    //            let finalDelayTime = abs(f2)
    //
    //            var originalDelayNode: Delay = Delay(node,
    //                                                 time: AUValue(finalDelayTime),
    //                                                 feedback: 0,
    //                                                 dryWetMix: 100)
    //
    //            (0..<delays).forEach { _ in
    //                originalDelayNode = addDelay(delayNode: originalDelayNode, delay: 2)
    //            }
    //
    //            return originalDelayNode
    //        }
    //        else {
    // TODO: no delay needed
    //            return Delay(node,
    //                         time: AUValue(0),
    //                         feedback: 0,
    //                         dryWetMix: 100)
    //        }
    //    }

    // a node that takes a delay node,
    // and wraps it in another delay node,
    // with the given time
    //    private func addDelay(delayNode: Delay, delay: Double) -> Delay {
    //        log("addDelay called")
    //        return Delay(delayNode,
    //                     time: AUValue(delay),
    //                     feedback: 0,
    //                     dryWetMix: 100)
    //    }
}

protocol StitchSoundPlayerDelegate: AnyObject, Sendable {
    // Used for hashing purposes
    var id: UUID { get }
    
    @MainActor func play()
    
    @MainActor func pause()
    
    @MainActor func stop()
    
    @MainActor var engine: AudioEngine { get }
    
    @MainActor var isRunning: Bool { get }
    
    static var permissionsCategory: AVAudioSession.Category { get }
}
