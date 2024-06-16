//
//  StitchSoundFile.swift
//  prototype
//
//  Created by Christian J Clampitt on 9/24/21.
//

import Foundation
import StitchSchemaKit
import AudioKit
import AVFoundation

final class StitchSoundFilePlayer: NSObject, StitchSoundPlayerDelegate {
    static let permissionsCategory = AVAudioSession.Category.playback

    var engine = AudioEngine()
    let player = AudioPlayer()

    // mixers don't need to be long lived, just the taps?
    private var ampTap: AmplitudeTap
    private var peakAmpTap: AmplitudeTap
    private var variSpeed: VariSpeed

    @MainActor
    init(url: URL,
         willLoop: Bool = true,
         rate: AUValue? = nil,
         jumpTime: Double? = nil) {
        // MARK: we had this in a Task object before but calling this async appeared to cause crashes
        try? AVAudioSession.enableSpeaker()

        do {
            try player.load(url: url)
        } catch {
            log("StitchSoundFilePlayer error: \(error)")
        }
        player.isLooping = willLoop

        // adding mixers for peak and average amplitude taps
        let mixer = Mixer(player)
        let mixer2 = Mixer(mixer)

        self.ampTap = AmplitudeTap(mixer, callbackQueue: .main)

        let peakAmpTap = AmplitudeTap(mixer2, callbackQueue: .main)
        peakAmpTap.analysisMode = .peak
        self.peakAmpTap = peakAmpTap

        let variSpeed = VariSpeed(mixer2)
        self.variSpeed = variSpeed

        // Note--this call from video init has some errors
        self.engine.output = variSpeed

        super.init()

        if let rate = rate {
            self.rate = rate
        }

        if let jumpTime = jumpTime {
            self.setJumpTime(jumpTime)
        }

        // Ensures the player always resets at 0 seconds. Calls using "seek" (on pulses)
        // may change this behavior otherwise.
        self.setPlayerLoop(time: .zero, enableInfiniteLoop: willLoop)
    }

    var isRunning: Bool {
        self.player.isStarted
    }

    var isLooping: Bool {
        get {
            self.player.isLooping
        }
        
        @MainActor
        set(newValue) {
            self.player.isLooping = newValue
            self.setPlayerLoop(time: .zero, enableInfiniteLoop: newValue)
        }
    }

    var rate: AUValue {
        get {
            self.variSpeed.rate
        }
        set(newValue) {
            self.variSpeed.rate = AUValue(newValue)
        }
    }

    func setJumpTime(_ jumpTime: Double) {
        self.player.seek(time: jumpTime)
    }

    var url: URL? { self.player.file?.url }

    @MainActor
    private func setPlayerLoop(time: TimeInterval, enableInfiniteLoop: Bool) {
        player.completionHandler = { [weak self] in
            self?.player.seek(time: time)

            if !enableInfiniteLoop {
                self?.pause()
            }
        }
    }

    /// Gets the player's current playback time.
    func getCurrentPlaybackTime() -> Double {
        // Calling getCurrentTime doesn't reset playback time after audio completes playing, so we compute
        // a modulo on the sound's duration.
        // TODO: getCurrentTime doesn't work perfectly have loop setting is toggled off and on.
        return self.player.currentTime.truncatingRemainder(dividingBy: self.duration)
    }

    var duration: Double {
        self.player.duration
    }

    var volume: Double {
        Double(self.ampTap.amplitude)
    }

    var peakVolume: Double {
        Double(self.peakAmpTap.amplitude)
    }

    func play() {
        self.player.play()
        self.ampTap.start()
        self.peakAmpTap.start()
    }

    func pause() {
        self.player.pause()
        self.ampTap.stop()
        self.peakAmpTap.stop()
    }

    func stop() {
        self.player.stop()
        self.ampTap.stop()
        self.peakAmpTap.stop()
    }
}
